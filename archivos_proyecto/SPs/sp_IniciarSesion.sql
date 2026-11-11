USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_IniciarSesion
 @in_Username VARCHAR(64)			-- usuario que intenta iniciar sesion
 , @in_Pass VARCHAR(128)			-- contraseña digitada
 , @in_IP VARCHAR(64) = '0.0.0.0'	-- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
 , @out_ResultCode INT = 0 OUTPUT	-- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_IniciarSesion @in_Username = 'amora', @in_Pass = 'AnaMora2026*', @in_IP = '127.0.0.1'
devuelve EsAdmin y Codigo, codigo 0 es login exitoso y 1 credenciales invalidas
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  DECLARE @IdUsuario INT;		-- id del usuario si las credenciales son correctas
  DECLARE @flagEsAdmin BIT = 0; -- 1 si el usuario es administrador

  -- busca el usuario comparando usuario y contraseña distinguiendo mayusculas y minusculas
  SELECT @IdUsuario = U.Id
   , @flagEsAdmin = U.EsAdministrador
  FROM dbo.Usuario AS U
  WHERE U.Username COLLATE Latin1_General_CS_AS = @in_Username
  AND U.Pass COLLATE Latin1_General_CS_AS = @in_Pass;

  -- registra en bitacora el login solo si las credenciales fueron validas, tipo de operacion 1
  INSERT INTO dbo.Bitacora (
   IdUsuario
   , IdTipoOperacion
   , JsonAntes
   , JsonDespues
   , IP
   , FechaHora
  )
  SELECT @IdUsuario
   , 1
   , NULL
   , NULL
   , @in_IP
   , GETDATE()
  WHERE @IdUsuario IS NOT NULL;

  -- devuelve si es administrador y el codigo de resultado
  SELECT
   @flagEsAdmin AS EsAdmin
   , CASE WHEN @IdUsuario IS NOT NULL THEN 0 ELSE 1 END AS Codigo;
 END TRY
 BEGIN CATCH
  SET @out_ResultCode = 50000;
 END CATCH;
END;
GO
