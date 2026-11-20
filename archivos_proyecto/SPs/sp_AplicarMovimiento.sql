USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_AplicarMovimiento] Fecha de script: 11/19/2026 10:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_AplicarMovimiento]
 @in_NumeroCuenta VARCHAR(32) -- numero de la cuenta sobre la que se aplica el movimiento
 , @in_NombreTipoMovimiento VARCHAR(64) -- nombre del tipo de movimiento tal como viene en el xml
 , @in_Monto DECIMAL(18,2) -- monto del movimiento en la moneda de la cuenta
 , @in_Descripcion VARCHAR(256) -- descripcion del movimiento tal como viene en el xml
 , @in_FechaOperacion DATE -- fecha de la simulacion en que ocurre el movimiento
 , @in_IdMovimientoXml INT = NULL -- id del movimiento en la lista cargada del xml, se guarda en el control para poder reiniciar
 , @out_ResultCode INT OUTPUT -- 0 exito, 50001 monto invalido, 50002 cuenta no existe, 50003 tipo no existe, 50004 sin estado abierto, 50005 saldo insuficiente, 50000 error de bd
AS
/*
ejemplo de ejecucion
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
  DECLARE @NomDepositoAtm VARCHAR(64) = 'Deposito ATM'; -- deposito en cajero automatico
  DECLARE @NomRetiroAtm VARCHAR(64) = 'Retiro ATM'; -- retiro en cajero automatico
  DECLARE @NomRetiroVentana VARCHAR(64) = 'Retiro Ventana'; -- retiro con cajero humano
  DECLARE @NomDepositoSinpe VARCHAR(64) = 'Deposito Sinpe'; -- transferencia sinpe recibida
  DECLARE @NomRetiroSinpe VARCHAR(64) = 'Retiro Sinpe'; -- transferencia sinpe enviada
  DECLARE @NomComisionSinpe VARCHAR(64) = 'Comision Sinpe'; -- comision por exceder el limite diario de sinpe

  -- datos de la cuenta
  DECLARE @IdCuenta INT; -- id de la cuenta
  DECLARE @SaldoActual DECIMAL(18,2); -- saldo de la cuenta antes del movimiento
  DECLARE @MontoMaxSinpe DECIMAL(18,2); -- monto diario de sinpe enviado sin comision segun el tipo de cuenta
  DECLARE @ComisionSinpe DECIMAL(18,2); -- comision por cada envio sinpe que supere el limite diario
  DECLARE @EmailPropietario VARCHAR(128); -- email del dueño de la cuenta, a donde llega el comprobante

  -- datos del tipo de movimiento
  DECLARE @IdTipoMovimiento INT; -- id del tipo de movimiento
  DECLARE @Accion VARCHAR(16); -- Credito suma al saldo, Debito resta
  DECLARE @flagGeneraComprobante BIT; -- 1 si el tipo de movimiento genera comprobante

  -- datos del estado de cuenta
  DECLARE @IdEstadoCuenta INT; -- id del estado de cuenta abierto en la fecha de la operacion
  DECLARE @SaldoMinimoEstado DECIMAL(18,2); -- saldo minimo que lleva el estado de cuenta antes del movimiento

  -- busca los datos de la cuenta y los limites de su tipo de cuenta, mapea el numero de cuenta a su id
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
  SELECT
   @IdEstadoCuenta = EC.Id
   , @SaldoMinimoEstado = EC.saldoMinimo
  FROM dbo.Estado_Cuenta AS EC
  WHERE EC.IdCuenta = @IdCuenta
  AND EC.fechaInicio <= @in_FechaOperacion
  AND EC.fechafin >= @in_FechaOperacion;

  -- validaciones, se sale antes de abrir la transaccion
  IF (@in_Monto IS NULL OR @in_Monto <= 0)
  BEGIN
   SET @out_ResultCode = 50001;
   RETURN;
  END;

  IF (@IdCuenta IS NULL)
  BEGIN
   SET @out_ResultCode = 50002;
   RETURN;
  END;

  IF (@IdTipoMovimiento IS NULL)
  BEGIN
   SET @out_ResultCode = 50003;
   RETURN;
  END;

  IF (@IdEstadoCuenta IS NULL)
  BEGIN
   SET @out_ResultCode = 50004;
   RETURN;
  END;

  -- calculos del movimiento
  DECLARE @SinpeAcumuladoHoy DECIMAL(18,2); -- suma de envios sinpe de la cuenta en la fecha de la operacion
  DECLARE @flagCobrarComisionSinpe BIT = 0; -- 1 si este envio supera el limite diario y se debe cobrar comision
  DECLARE @MontoComision DECIMAL(18,2) = 0; -- monto de la comision sinpe a cobrar, 0 si no aplica
  DECLARE @SaldoTrasMovimiento DECIMAL(18,2); -- saldo despues de aplicar solo el movimiento principal
  DECLARE @SaldoFinal DECIMAL(18,2); -- saldo despues del movimiento principal y la comision
  DECLARE @SaldoMinimoNuevo DECIMAL(18,2); -- saldo minimo del estado de cuenta despues del movimiento

  -- suma los envios sinpe que la cuenta ya hizo ese dia, no incluye las comisiones
  SELECT
   @SinpeAcumuladoHoy = SUM(M.Monto)
  FROM dbo.Movimiento AS M
  INNER JOIN dbo.Tipos_Movimiento AS TM ON TM.Id = M.IdTipoMovimiento
  WHERE M.IdCuenta = @IdCuenta
  AND M.Fecha = @in_FechaOperacion
  AND TM.Nombre = @NomRetiroSinpe;

  -- si todavia no hubo envios sinpe en el dia la suma queda en null
  IF (@SinpeAcumuladoHoy IS NULL)
  BEGIN
   SET @SinpeAcumuladoHoy = 0;
  END;

  -- cobra comision solo si es un envio sinpe y con este monto se supera el limite diario
  IF (@in_NombreTipoMovimiento = @NomRetiroSinpe AND @SinpeAcumuladoHoy + @in_Monto > @MontoMaxSinpe)
  BEGIN
   SET @flagCobrarComisionSinpe = 1;
   SET @MontoComision = @ComisionSinpe;
  END;

  -- saldo tras el movimiento principal, suma si es credito y resta si es debito
  SET @SaldoTrasMovimiento = @SaldoActual + @in_Monto;
  IF (@Accion = 'Debito')
  BEGIN
   SET @SaldoTrasMovimiento = @SaldoActual - @in_Monto;
  END;

  -- saldo final tras restar la comision
  SET @SaldoFinal = @SaldoTrasMovimiento - @MontoComision;

  -- un debito no puede dejar la cuenta en saldo negativo
  IF (@Accion = 'Debito' AND @SaldoFinal < 0)
  BEGIN
   SET @out_ResultCode = 50005;
   RETURN;
  END;

  -- el saldo minimo del estado baja solo si el nuevo saldo es menor que el que ya tenia
  SET @SaldoMinimoNuevo = @SaldoMinimoEstado;
  IF (@SaldoFinal < @SaldoMinimoEstado)
  BEGIN
   SET @SaldoMinimoNuevo = @SaldoFinal;
  END;

  -- incrementos de los contadores del estado de cuenta, cada uno queda en 0 si el movimiento no aplica
  DECLARE @IncRetiros INT = 0; -- 1 si es retiro atm o de ventana
  DECLARE @IncDepositos INT = 0; -- 1 si es deposito atm o de ventana
  DECLARE @IncSinpeEntrantes INT = 0; -- 1 si es deposito sinpe
  DECLARE @IncSinpeSalientes INT = 0; -- 1 si es retiro sinpe
  DECLARE @IncOperacionesAtm INT = 0; -- 1 si es operacion en atm
  DECLARE @IncOperacionesHumano INT = 0; -- 1 si es operacion con cajero humano

  IF (@in_NombreTipoMovimiento IN (@NomRetiroAtm, @NomRetiroVentana))
  BEGIN
   SET @IncRetiros = 1;
  END;

  IF (@in_NombreTipoMovimiento IN (@NomDepositoAtm, @NomDepositoVentana))
  BEGIN
   SET @IncDepositos = 1;
  END;

  IF (@in_NombreTipoMovimiento = @NomDepositoSinpe)
  BEGIN
   SET @IncSinpeEntrantes = 1;
  END;

  IF (@in_NombreTipoMovimiento = @NomRetiroSinpe)
  BEGIN
   SET @IncSinpeSalientes = 1;
  END;

  IF (@in_NombreTipoMovimiento IN (@NomRetiroAtm, @NomDepositoAtm))
  BEGIN
   SET @IncOperacionesAtm = 1;
  END;

  IF (@in_NombreTipoMovimiento IN (@NomRetiroVentana, @NomDepositoVentana))
  BEGIN
   SET @IncOperacionesHumano = 1;
  END;

  -- arma el comprobante que llega al email del dueño
  DECLARE @IdComprobante INT; -- id del comprobante insertado, queda en null si el movimiento no genera comprobante
  DECLARE @AsuntoComprobante VARCHAR(128) = 'Comprobante de ' + @in_NombreTipoMovimiento; -- asunto del comprobante
  DECLARE @CuerpoComprobante VARCHAR(512) = @in_NombreTipoMovimiento + ' por ' + CONVERT(VARCHAR(32), @in_Monto)
   + ' en la cuenta ' + @in_NumeroCuenta
   + ' el ' + CONVERT(VARCHAR(16), @in_FechaOperacion, 23)
   + ' - ' + @in_Descripcion
   + ' - nuevo saldo ' + CONVERT(VARCHAR(32), @SaldoTrasMovimiento); -- cuerpo del comprobante

  -- todo lo que afecta a la cuenta se aplica en una sola transaccion
  -- se actualiza en orden de importancia, de lo menos importante a lo mas importante, el saldo de la cuenta es lo ultimo
  BEGIN TRANSACTION tAplicarMovimiento;

  -- inserta el comprobante solo cuando el tipo de movimiento lo indica
  INSERT INTO dbo.Comprobante (
   EmailDestino
   , Asunto
   , Cuerpo
  )
  SELECT
   @EmailPropietario
   , @AsuntoComprobante
   , @CuerpoComprobante
  WHERE @flagGeneraComprobante = 1;

  -- guarda el id del comprobante, en este alcance solo este insert genera una identidad
  SET @IdComprobante = SCOPE_IDENTITY();

  -- guarda el ultimo movimiento procesado de la fecha para poder reiniciar la simulacion
  UPDATE dbo.Simulacion_Control
  SET UltimoMovimientoProcesado = @in_IdMovimientoXml
  WHERE FechaOperacion = @in_FechaOperacion
  AND @in_IdMovimientoXml IS NOT NULL;

  -- inserta el movimiento principal con el saldo que quedo despues de el
  INSERT INTO dbo.Movimiento (
   IdCuenta
   , IdTipoMovimiento
   , IdComprobante
   , Fecha
   , Monto
   , Descripcion
   , NuevoSaldo
  )
  VALUES (
   @IdCuenta
   , @IdTipoMovimiento
   , @IdComprobante
   , @in_FechaOperacion
   , @in_Monto
   , @in_Descripcion
   , @SaldoTrasMovimiento
  );

  -- inserta el segundo movimiento, la comision sinpe, solo cuando se debe cobrar
  INSERT INTO dbo.Movimiento (
   IdCuenta
   , IdTipoMovimiento
   , IdComprobante
   , Fecha
   , Monto
   , Descripcion
   , NuevoSaldo
  )
  SELECT
   @IdCuenta
   , TM.Id
   , NULL
   , @in_FechaOperacion
   , @MontoComision
   , 'Comision por exceder el limite diario de sinpe'
   , @SaldoFinal
  FROM dbo.Tipos_Movimiento AS TM
  WHERE TM.Nombre = @NomComisionSinpe
  AND @flagCobrarComisionSinpe = 1;

  -- actualiza el saldo final, el saldo minimo y los contadores del estado de cuenta abierto
  UPDATE dbo.Estado_Cuenta
  SET
   saldo_final = @SaldoFinal
   , saldoMinimo = @SaldoMinimoNuevo
   , cantRetiros = cantRetiros + @IncRetiros
   , cantDepositos = cantDepositos + @IncDepositos
   , cantSinpeEntrantes = cantSinpeEntrantes + @IncSinpeEntrantes
   , cantSinpeSalientes = cantSinpeSalientes + @IncSinpeSalientes
   , cantOperacionesATM = cantOperacionesATM + @IncOperacionesAtm
   , cantOperacionesHumano = cantOperacionesHumano + @IncOperacionesHumano
  WHERE Id = @IdEstadoCuenta;

  -- actualiza el saldo de la cuenta, es lo mas consultado por eso va al final
  UPDATE dbo.Cuenta
  SET Saldo = @SaldoFinal
  WHERE Id = @IdCuenta;

  COMMIT TRANSACTION tAplicarMovimiento;
 END TRY
 BEGIN CATCH
  -- ante cualquier error se deshace todo lo de la cuenta
  IF @@TRANCOUNT > 0
  BEGIN
   ROLLBACK TRANSACTION;
  END;
  SET @out_ResultCode = 50000;
 END CATCH;
END;
