CREATE OR ALTER PROCEDURE dbo.sp_ConsultarEstadosDeCuenta
 @in_Username VARCHAR(50), -- usuario que realiza la consulta
 @in_IdCuenta INT, -- id de la cuenta cuyos estados de cuenta se listan
 @in_IP VARCHAR(50) = '0.0.0.0' -- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ConsultarEstadosDeCuenta @in_Username = 'amora', @in_IdCuenta = 1, @in_IP = '127.0.0.1'
devuelve todos los estados de la cuenta del mas reciente al mas antiguo
*/
BEGIN
 SET NOCOUNT ON;

 DECLARE @IdUsuario INT; -- id del usuario que consulta
 DECLARE @EsAdmin BIT = 0; -- 1 si el usuario es administrador

 -- mapea el username al id y a los privilegios del usuario
 SELECT @IdUsuario = U.Id, @EsAdmin = U.EsAdministrador
 FROM dbo.Usuario AS U
 WHERE U.Username = @in_Username;

 -- lista los estados de la cuenta, solo si es administrador o la cuenta es del usuario
 SELECT
  EC.Id AS IdEstadoCuenta,
  C.NumeroCuenta,
  TM.Simbolo AS SimboloMoneda,
  EC.fechaInicio AS FechaInicio,
  EC.fechafin AS FechaFin,
  EC.saldoinicial AS SaldoInicial,
  EC.saldoMinimo AS SaldoMinimo,
  EC.saldo_final AS SaldoFinal,
  EC.interesesAcumulados AS InteresesAcumulados,
  EC.cantOperacionesATM AS CantOperacionesATM,
  EC.cantOperacionesHumano AS CantOperacionesHumano,
  EC.cantSinpeEntrantes AS CantSinpeEntrantes,
  EC.cantSinpeSalientes AS CantSinpeSalientes,
  EC.cantRetiros AS CantRetiros,
  EC.cantDepositos AS CantDepositos
 FROM dbo.Estado_Cuenta AS EC
 INNER JOIN dbo.Cuenta AS C ON C.Id = EC.IdCuenta
 INNER JOIN dbo.Tipo_Cuenta_Ahorros AS TCA ON TCA.Id = C.IdTipoCuenta
 INNER JOIN dbo.Tipo_Moneda AS TM ON TM.Id = TCA.IdTipoMoneda
 WHERE EC.IdCuenta = @in_IdCuenta
 AND @IdUsuario IS NOT NULL
 AND (
  @EsAdmin = 1
  OR EXISTS (
   SELECT 1
   FROM dbo.Usuarios_Ver AS UV
   WHERE UV.IdUsuario = @IdUsuario
   AND UV.IdCuenta = EC.IdCuenta
  )
 )
 ORDER BY EC.fechaInicio DESC;

 -- registra en bitacora la consulta, tipo de operacion 7 consultar estado de cuenta
 INSERT INTO dbo.Bitacora (IdUsuario, IdTipoOperacion, IP, FechaHora)
 SELECT @IdUsuario, 7, @in_IP, GETDATE()
 WHERE @IdUsuario IS NOT NULL;
END;
