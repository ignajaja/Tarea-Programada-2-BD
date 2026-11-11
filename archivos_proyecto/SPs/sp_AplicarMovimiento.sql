USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_AplicarMovimiento
 @in_NumeroCuenta VARCHAR(32) 			-- numero de la cuenta sobre la que se aplica el movimiento
 , @in_NombreTipoMovimiento VARCHAR(64) -- nombre del tipo de movimiento que viene en el xml
 , @in_Monto DECIMAL(18,2) 				-- monto del movimiento en la moneda de la cuenta
 , @in_Descripcion VARCHAR(256) 		-- descripcion del movimiento como viene en el xml
 , @in_FechaOperacion DATE 				-- fecha de la simulacion en que ocurre el movimiento
 , @in_IdMovimientoXml INT = NULL 		-- id del movimiento en la lista cargada del xml, se guarda en el control para poder reiniciar
 , @out_ResultCode INT OUTPUT 			-- 0 exito, 50001 monto invalido, 50002 cuenta no existe, 50003 tipo no existe, 50004 sin estado abierto, 50005 saldo insuficiente, 50000 error de bd
AS
/*
ejemplo de ejecucion:
 DECLARE @resultado INT
 EXEC dbo.sp_AplicarMovimiento
  @in_NumeroCuenta = '11000001'
  , @in_NombreTipoMovimiento = 'Retiro Sinpe'
  , @in_Monto = 5000.00
  , @in_Descripcion = 'A Lola La Trailera'
  , @in_FechaOperacion = '2026-03-02'
  , @in_IdMovimientoXml = NULL
  , @out_ResultCode = @resultado OUTPUT
 SELECT @resultado AS ResultCode
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  -- inicia en exito
  SET @out_ResultCode = 0;

  -- nombres de los tipos de movimiento del catalogo que tienen reglas especiales
  DECLARE @NomDepositoVentana VARCHAR(64) = 'Deposito Ventana'; -- deposito con cajero humano
  DECLARE @NomDepositoAtm VARCHAR(64) = 'Deposito ATM'; 		-- deposito en cajero automatico
  DECLARE @NomRetiroAtm VARCHAR(64) = 'Retiro ATM'; 			-- retiro en cajero automatico
  DECLARE @NomRetiroVentana VARCHAR(64) = 'Retiro Ventana'; 	-- retiro con cajero humano
  DECLARE @NomDepositoSinpe VARCHAR(64) = 'Deposito Sinpe'; 	-- transferencia sinpe recibida
  DECLARE @NomRetiroSinpe VARCHAR(64) = 'Retiro Sinpe'; 		-- transferencia sinpe enviada
  DECLARE @NomComisionSinpe VARCHAR(64) = 'Comision Sinpe'; 	-- comision por exceder el limite diario de sinpe

  -- datos de la cuenta
  DECLARE @IdCuenta INT; -- id de la cuenta
  DECLARE @SaldoActual DECIMAL(18,2); 		-- saldo de la cuenta antes del movimiento
  DECLARE @MontoMaxSinpe DECIMAL(18,2); 	-- monto diario de sinpe enviado sin comision segun el tipo de cuenta
  DECLARE @ComisionSinpe DECIMAL(18,2); 	-- comision por cada envio sinpe que supere el limite diario
  DECLARE @EmailPropietario VARCHAR(128); 	-- email del dueño de la cuenta, a donde llega el comprobante

  -- datos del tipo de movimiento
  DECLARE @IdTipoMovimiento INT; 		-- id del tipo de movimiento
  DECLARE @Accion VARCHAR(16); 			-- Credito suma al saldo, Debito resta
  DECLARE @flagGeneraComprobante BIT; 	-- 1 si el tipo de movimiento genera comprobante

  -- datos del estado de cuenta
  DECLARE @IdEstadoCuenta INT; -- id del estado de cuenta abierto en la fecha de la operacion

  -- calculos del movimiento
  DECLARE @SinpeAcumuladoHoy DECIMAL(18,2); 	-- suma de envios sinpe de la cuenta en la fecha de la operacion
  DECLARE @flagCobrarComisionSinpe BIT; 		-- 1 si este envio supera el limite diario y se debe cobrar comision
  DECLARE @MontoComision DECIMAL(18,2); 		-- monto de la comision sinpe a cobrar, 0 si no aplica
  DECLARE @SaldoTrasMovimiento DECIMAL(18,2); 	-- saldo despues de aplicar solo el movimiento principal
  DECLARE @SaldoFinal DECIMAL(18,2); 			-- saldo despues del movimiento principal y la comision
  DECLARE @IdMovimiento INT; 					-- id del movimiento principal insertado, se usa para el comprobante
  DECLARE @AsuntoComprobante VARCHAR(128); 		-- asunto del comprobante que se envia al email
  DECLARE @CuerpoComprobante VARCHAR(512); 		-- cuerpo del comprobante

  -- mapea el numero de cuenta a su id y trae los limites de su tipo de cuenta y el email del dueño
  SELECT
   @IdCuenta = C.Id
   , @SaldoActual = C.Saldo
   , @MontoMaxSinpe = TCA.MontoMaxSinpeDiario
   , @ComisionSinpe = TCA.ComisionSinpe
   , @EmailPropietario = P.Email
  FROM dbo.Cuenta AS C
  INNER JOIN dbo.Tipo_Cuenta_Ahorros AS TCA ON TCA.Id = C.IdTipoCuenta
  INNER JOIN dbo.Persona AS P ON P.Id = C.IdPersona
  WHERE C.NumeroCuenta = @in_NumeroCuenta;

  -- mapea el nombre del tipo de movimiento a su id, su accion y si genera comprobante
  SELECT
   @IdTipoMovimiento = TM.Id
   , @Accion = TM.Accion
   , @flagGeneraComprobante = TM.flagGeneraComprobante
  FROM dbo.Tipos_Movimiento AS TM
  WHERE TM.Nombre = @in_NombreTipoMovimiento;

  -- busca el estado de cuenta cuyo rango de fechas contiene la fecha de la operacion
  SELECT TOP 1
   @IdEstadoCuenta = EC.Id
  FROM dbo.Estado_Cuenta AS EC
  WHERE EC.IdCuenta = @IdCuenta
  AND EC.fechaInicio <= @in_FechaOperacion
  AND EC.fechafin >= @in_FechaOperacion
  ORDER BY EC.fechaInicio DESC;

  -- suma los envios sinpe que la cuenta ya hizo ese dia sin contar las comisiones
  SELECT
   @SinpeAcumuladoHoy = ISNULL(SUM(M.Monto), 0)
  FROM dbo.Movimiento AS M
  INNER JOIN dbo.Tipos_Movimiento AS TM ON TM.Id = M.IdTipoMovimiento
  WHERE M.IdCuenta = @IdCuenta
  AND M.Fecha = @in_FechaOperacion
  AND TM.Nombre = @NomRetiroSinpe;

  -- cobra comision solo si es un envio sinpe y con este monto se supera el limite diario
  SET @flagCobrarComisionSinpe = CASE
   WHEN (@in_NombreTipoMovimiento = @NomRetiroSinpe
    AND @MontoMaxSinpe IS NOT NULL
    AND @SinpeAcumuladoHoy + @in_Monto > @MontoMaxSinpe) THEN 1
   ELSE 0
  END;

  -- monto de la comision, queda en 0 si no se cobra
  SET @MontoComision = CASE WHEN @flagCobrarComisionSinpe = 1 THEN ISNULL(@ComisionSinpe, 0) ELSE 0 END;

  -- saldo tras el movimiento principal, suma si es credito y resta si es debito
  SET @SaldoTrasMovimiento = @SaldoActual + CASE WHEN @Accion = 'Credito' THEN @in_Monto ELSE -@in_Monto END;

  -- saldo final tras restar la comision
  SET @SaldoFinal = @SaldoTrasMovimiento - @MontoComision;

  -- determina el codigo de error con la primera condicion que se cumpla
  SET @out_ResultCode = CASE
   WHEN (@in_Monto IS NULL OR @in_Monto <= 0) THEN 50001 	--monto invalido
   WHEN @IdCuenta IS NULL THEN 50002						--cuenta no existe
   WHEN @IdTipoMovimiento IS NULL THEN 50003				--tipo no existe
   WHEN @IdEstadoCuenta IS NULL THEN 50004					--sin estado abierto
   WHEN (@Accion = 'Debito' AND @SaldoFinal < 0) THEN 50005 --saldo insuficiente
   ELSE 0
  END;

  -- si hubo error se sale antes de abrir la transaccion
  IF @out_ResultCode > 0
  BEGIN
   RETURN;
  END;

  -- arma el comprobante que llega al email del dueño
  SET @AsuntoComprobante = LEFT(CONCAT('Comprobante de ', @in_NombreTipoMovimiento), 128);
  SET @CuerpoComprobante = LEFT(CONCAT(
   @in_NombreTipoMovimiento, ' por ', FORMAT(@in_Monto, 'N2')
   , ' en la cuenta ', @in_NumeroCuenta
   , ' el ', CONVERT(VARCHAR(16), @in_FechaOperacion, 23)
   , ' - ', @in_Descripcion
   , ' - nuevo saldo ', FORMAT(@SaldoTrasMovimiento, 'N2')
  ), 512);

  -- transaccion para aplicar el movimiento
  BEGIN TRANSACTION tAplicarMovimiento;

  -- actualiza el saldo de la cuenta
  UPDATE dbo.Cuenta
  SET Saldo = @SaldoFinal
  WHERE Id = @IdCuenta;

  -- insertar el movimiento con el saldo que quedo despues de el
  INSERT INTO dbo.Movimiento (
   IdCuenta
   , IdTipoMovimiento
   , Fecha
   , Monto
   , Descripcion
   , NuevoSaldo
  )
  VALUES (
   @IdCuenta
   , @IdTipoMovimiento
   , @in_FechaOperacion
   , @in_Monto
   , @in_Descripcion
   , @SaldoTrasMovimiento
  );

  -- guardar el id del movimiento
  SET @IdMovimiento = SCOPE_IDENTITY();

  -- inserta comision sinpe si se debe cobrar
  INSERT INTO dbo.Movimiento (
   IdCuenta
   , IdTipoMovimiento
   , Fecha
   , Monto
   , Descripcion
   , NuevoSaldo
  )
  SELECT
   @IdCuenta
   , TM.Id
   , @in_FechaOperacion
   , @MontoComision
   , 'Comision por exceder el limite diario de sinpe'
   , @SaldoFinal
  FROM dbo.Tipos_Movimiento AS TM
  WHERE TM.Nombre = @NomComisionSinpe
  AND @flagCobrarComisionSinpe = 1;

  -- genera el comprobante si el tipo de movimiento lo indica
  INSERT INTO dbo.Comprobante_Movimiento (
   IdMovimiento
   , EmailDestino
   , Asunto
   , Cuerpo
  )
  SELECT
   @IdMovimiento
   , @EmailPropietario
   , @AsuntoComprobante
   , @CuerpoComprobante
  WHERE @flagGeneraComprobante = 1;

  -- actualiza el saldo final, el saldo minimo y demas contadores del estado de cuenta
  UPDATE dbo.Estado_Cuenta
  SET
   saldo_final = @SaldoFinal
   , saldoMinimo = CASE WHEN saldoMinimo IS NULL OR @SaldoFinal < saldoMinimo THEN @SaldoFinal ELSE saldoMinimo END
   , cantRetiros = ISNULL(cantRetiros, 0) + CASE WHEN @in_NombreTipoMovimiento IN (@NomRetiroAtm, @NomRetiroVentana) THEN 1 ELSE 0 END
   , cantDepositos = ISNULL(cantDepositos, 0) + CASE WHEN @in_NombreTipoMovimiento IN (@NomDepositoVentana, @NomDepositoAtm) THEN 1 ELSE 0 END
   , cantSinpeEntrantes = ISNULL(cantSinpeEntrantes, 0) + CASE WHEN @in_NombreTipoMovimiento = @NomDepositoSinpe THEN 1 ELSE 0 END
   , cantSinpeSalientes = ISNULL(cantSinpeSalientes, 0) + CASE WHEN @in_NombreTipoMovimiento = @NomRetiroSinpe THEN 1 ELSE 0 END
   , cantOperacionesATM = cantOperacionesATM + CASE WHEN @in_NombreTipoMovimiento IN (@NomRetiroAtm, @NomDepositoAtm) THEN 1 ELSE 0 END
   , cantOperacionesHumano = cantOperacionesHumano + CASE WHEN @in_NombreTipoMovimiento IN (@NomRetiroVentana, @NomDepositoVentana) THEN 1 ELSE 0 END
  WHERE Id = @IdEstadoCuenta;

  -- guardar el ultimo movimiento procesado de la fecha
  UPDATE dbo.Simulacion_Control
  SET UltimoMovimientoProcesado = @in_IdMovimientoXml
  WHERE FechaOperacion = @in_FechaOperacion
  AND @in_IdMovimientoXml IS NOT NULL;

  COMMIT TRANSACTION tAplicarMovimiento;
 END TRY
 BEGIN CATCH
  -- ante cualquier error se deshace todo
  IF @@TRANCOUNT > 0
  BEGIN
   ROLLBACK TRANSACTION;
  END;
  SET @out_ResultCode = 50000;
 END CATCH;
END;
GO
