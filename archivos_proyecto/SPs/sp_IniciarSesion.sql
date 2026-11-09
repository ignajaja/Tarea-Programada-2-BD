CREATE OR ALTER PROCEDURE dbo.sp_IniciarSesion
 @in_Username VARCHAR(50), -- usuario que intenta iniciar sesion
 @in_Pass VARCHAR(100), -- contraseña digitada
 @in_IP VARCHAR(50) = '0.0.0.0' -- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_IniciarSesion @in_Username = 'amora', @in_Pass = 'AnaMora2026*', @in_IP = '127.0.0.1'
devuelve EsAdmin y Codigo, codigo 0 es login exitoso y 1 credenciales invalidas
*/
BEGIN
 SET NOCOUNT ON;

 DECLARE @IdUsuario INT; -- id del usuario si las credenciales son correctas
 DECLARE @EsAdmin BIT = 0; -- 1 si el usuario es administrador

 -- busca el usuario comparando usuario y contraseña distinguiendo mayusculas y minusculas
 SELECT @IdUsuario = U.Id, @EsAdmin = U.EsAdministrador
 FROM dbo.Usuario AS U
 WHERE U.Username COLLATE Latin1_General_CS_AS = @in_Username
 AND U.Pass COLLATE Latin1_General_CS_AS = @in_Pass;

 -- registra en bitacora el login solo si las credenciales fueron validas, tipo de operacion 1
 INSERT INTO dbo.Bitacora (IdUsuario, IdTipoOperacion, IP, FechaHora)
 SELECT @IdUsuario, 1, @in_IP, GETDATE()
 WHERE @IdUsuario IS NOT NULL;

 -- devuelve si es administrador y el codigo de resultado
 SELECT
  @EsAdmin AS EsAdmin,
  CASE WHEN @IdUsuario IS NOT NULL THEN 0 ELSE 1 END AS Codigo;
END;
