USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_ConsultarMovimientosEstadoCuenta
 @in_Username VARCHAR(64) 			-- usuario que realiza la consulta
 , @in_IdEstadoCuenta INT 			-- id del estado de cuenta seleccionado
 , @in_IP VARCHAR(64) = '0.0.0.0' 	-- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
 , @out_ResultCode INT = 0 OUTPUT 	-- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ConsultarMovimientosEstadoCuenta @in_Username = 'amora', @in_IdEstadoCuenta = 1, @in_IP = '127.0.0.1'
devuelve los movimientos del estado de cuenta en orden cronologico
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

  -- lista los movimientos cuya fecha cae dentro del rango del estado de cuenta
  -- solo si es administrador o la cuenta del estado es del usuario
  SELECT
   M.Fecha
   , TMov.Nombre AS TipoMovimiento
   , M.Monto
   , TMon.Simbolo AS SimboloMoneda
   , M.Descripcion
   , M.NuevoSaldo
  FROM dbo.Estado_Cuenta AS EC
  INNER JOIN dbo.Movimiento AS M ON M.IdCuenta = EC.IdCuenta
   AND M.Fecha BETWEEN EC.fechaInicio AND EC.fechafin
  INNER JOIN dbo.Tipos_Movimiento AS TMov ON TMov.Id = M.IdTipoMovimiento
  INNER JOIN dbo.Cuenta AS C ON C.Id = EC.IdCuenta
  INNER JOIN dbo.Tipo_Cuenta_Ahorros AS TCA ON TCA.Id = C.IdTipoCuenta
  INNER JOIN dbo.Tipo_Moneda AS TMon ON TMon.Id = TCA.IdTipoMoneda
  WHERE EC.Id = @in_IdEstadoCuenta
  AND @IdUsuario IS NOT NULL
  AND (
   @flagEsAdmin = 1
   OR EXISTS (
    SELECT 1
    FROM dbo.Usuarios_Ver AS UV
    WHERE UV.IdUsuario = @IdUsuario
    AND UV.IdCuenta = EC.IdCuenta
   )
  )
  ORDER BY M.Fecha, M.Id;

  -- registra en bitacora la consulta, tipo de operacion 8 consultar movimientos de estado de cuenta
  INSERT INTO dbo.Bitacora (
   IdUsuario
   , IdTipoOperacion
   , JsonAntes
   , JsonDespues
   , IP
   , FechaHora
  )
  SELECT @IdUsuario
   , 8
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
GO
