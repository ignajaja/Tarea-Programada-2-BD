USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_ConsultarEstadosDeCuenta] Fecha de script: 11/19/2026 10:58:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_ConsultarEstadosDeCuenta]
 @in_Username VARCHAR(64) -- usuario que realiza la consulta
 , @in_IdCuenta INT -- id de la cuenta cuyos estados de cuenta se listan
 , @in_IP VARCHAR(64) = '0.0.0.0' -- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
 , @out_ResultCode INT = 0 OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ConsultarEstadosDeCuenta @in_Username = 'amora', @in_IdCuenta = 1, @in_IP = '127.0.0.1'
devuelve todos los estados de la cuenta del mas reciente al mas antiguo
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  DECLARE @IdUsuario INT; -- id del usuario que consulta
  DECLARE @flagEsAdmin BIT = 0; -- 1 si el usuario es administrador
  DECLARE @flagTieneAcceso BIT = 0; -- 1 si el usuario puede ver la cuenta
  DECLARE @IdCuenta INT = @in_IdCuenta; -- id de la cuenta consultada

  -- mapea el username al id y a los privilegios del usuario
  SELECT @IdUsuario = U.Id
   , @flagEsAdmin = U.EsAdministrador
  FROM dbo.Usuario AS U
  WHERE U.Username = @in_Username;

  -- el cliente solo puede ver las cuentas que tiene asignadas
  SELECT @flagTieneAcceso = 1
  FROM dbo.Usuarios_Ver AS UV
  WHERE UV.IdUsuario = @IdUsuario
  AND UV.IdCuenta = @IdCuenta;

  -- el administrador puede ver todas las cuentas
  IF (@flagEsAdmin = 1)
  BEGIN
   SET @flagTieneAcceso = 1;
  END;

  -- lista los estados de la cuenta, solo si es administrador o la cuenta es del usuario
  SELECT
   EC.Id AS IdEstadoCuenta
   , C.NumeroCuenta
   , TM.Simbolo AS SimboloMoneda
   , EC.fechaInicio AS FechaInicio
   , EC.fechafin AS FechaFin
   , EC.saldoinicial AS SaldoInicial
   , EC.saldoMinimo AS SaldoMinimo
   , EC.saldo_final AS SaldoFinal
   , EC.interesesAcumulados AS InteresesAcumulados
   , EC.cantOperacionesATM AS CantOperacionesATM
   , EC.cantOperacionesHumano AS CantOperacionesHumano
   , EC.cantSinpeEntrantes AS CantSinpeEntrantes
   , EC.cantSinpeSalientes AS CantSinpeSalientes
   , EC.cantRetiros AS CantRetiros
   , EC.cantDepositos AS CantDepositos
  FROM dbo.Estado_Cuenta AS EC
  INNER JOIN dbo.Cuenta AS C ON C.Id = EC.IdCuenta
  INNER JOIN dbo.Tipo_Cuenta_Ahorros AS TCA ON TCA.Id = C.IdTipoCuenta
  INNER JOIN dbo.Tipo_Moneda AS TM ON TM.Id = TCA.IdTipoMoneda
  WHERE EC.IdCuenta = @IdCuenta
  AND @flagTieneAcceso = 1
  ORDER BY EC.fechaInicio DESC;

  -- registra en bitacora la consulta, tipo de operacion 7 consultar estado de cuenta
  INSERT INTO dbo.Bitacora (
   IdUsuario
   , IdTipoOperacion
   , JsonAntes
   , JsonDespues
   , IP
   , FechaHora
  )
  SELECT @IdUsuario
   , 7
   , NULL
   , NULL
   , @in_IP
   , GETDATE()
  WHERE @IdUsuario IS NOT NULL;
 END TRY
 BEGIN CATCH
  SET @out_ResultCode = 50000;
 END CATCH;
END;
