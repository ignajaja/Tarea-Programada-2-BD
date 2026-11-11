USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_CerrarSesion
 @in_Username VARCHAR(64) 			-- usuario que cierra sesion
 , @in_IP VARCHAR(64) = '0.0.0.0' 	-- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
 , @out_ResultCode INT = 0 OUTPUT 	-- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_CerrarSesion @in_Username = 'amora', @in_IP = '127.0.0.1'
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  DECLARE @IdUsuario INT; -- id del usuario que cierra sesion

  -- mapea el username al id del usuario
  SELECT @IdUsuario = U.Id
  FROM dbo.Usuario AS U
  WHERE U.Username = @in_Username;

  -- registra en bitacora el logout, tipo de operacion 2
  INSERT INTO dbo.Bitacora (
   IdUsuario
   , IdTipoOperacion
   , JsonAntes
   , JsonDespues
   , IP
   , FechaHora
  )
  SELECT @IdUsuario
   , 2
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
