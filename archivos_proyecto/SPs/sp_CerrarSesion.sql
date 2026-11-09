CREATE OR ALTER PROCEDURE dbo.sp_CerrarSesion
 @in_Username VARCHAR(50), -- usuario que cierra sesion
 @in_IP VARCHAR(50) = '0.0.0.0' -- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_CerrarSesion @in_Username = 'amora', @in_IP = '127.0.0.1'
*/
BEGIN
 SET NOCOUNT ON;

 DECLARE @IdUsuario INT; -- id del usuario que cierra sesion

 -- mapea el username al id del usuario
 SELECT @IdUsuario = U.Id
 FROM dbo.Usuario AS U
 WHERE U.Username = @in_Username;

 -- registra en bitacora el logout, tipo de operacion 2
 INSERT INTO dbo.Bitacora (IdUsuario, IdTipoOperacion, IP, FechaHora)
 SELECT @IdUsuario, 2, @in_IP, GETDATE()
 WHERE @IdUsuario IS NOT NULL;
END;
