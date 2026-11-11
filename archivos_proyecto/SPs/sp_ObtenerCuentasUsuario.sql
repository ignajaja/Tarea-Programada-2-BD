USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerCuentasUsuario
 @in_Username VARCHAR(64) 			-- usuario cuyas cuentas se consultan
 , @out_ResultCode INT = 0 OUTPUT 	-- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ObtenerCuentasUsuario @in_Username = 'amora'
administrador ve todas las cuentas, un cliente solo las que tiene permiso de ver
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  DECLARE @IdUsuario INT; 		-- id del usuario que consulta
  DECLARE @flagEsAdmin BIT = 0; -- 1 si el usuario es administrador

  -- mapea el username al id y a los privilegios del usuario
  SELECT @IdUsuario = U.Id
   , @flagEsAdmin = U.EsAdministrador
  FROM dbo.Usuario AS U
  WHERE U.Username = @in_Username;

  -- lista las cuentas con su moneda y saldo, filtradas por permiso salvo que sea administrador
  SELECT
   C.Id AS IdCuenta
   , C.NumeroCuenta
   , C.Saldo
   , TM.Simbolo AS SimboloMoneda
  FROM dbo.Cuenta AS C
  INNER JOIN dbo.Tipo_Cuenta_Ahorros AS TCA ON TCA.Id = C.IdTipoCuenta
  INNER JOIN dbo.Tipo_Moneda AS TM ON TM.Id = TCA.IdTipoMoneda
  WHERE @IdUsuario IS NOT NULL
  AND (
   @flagEsAdmin = 1
   OR EXISTS (
    SELECT 1
    FROM dbo.Usuarios_Ver AS UV
    WHERE UV.IdUsuario = @IdUsuario
    AND UV.IdCuenta = C.Id
   )
  )
  ORDER BY C.NumeroCuenta;
 END TRY
 BEGIN CATCH
  SET @out_ResultCode = 50000;
 END CATCH;
END;
GO
