CREATE OR ALTER PROCEDURE dbo.sp_CerrarSesion
    @in_Username VARCHAR(64),          -- usuario que cierra sesión
    @in_IP VARCHAR(64) = '0.0.0.0'     -- ip por defecto si no se recibe desde views.py
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- obtener el id del usuario que cierra sesión
    DECLARE @IdUsuario INT;            -- id numérico del usuario
    SELECT @IdUsuario = Id 
    FROM Usuario 
    WHERE Username = @in_Username;

    -- registrar el cierre de sesión en la bitácora (tipo de operación 2)
    INSERT INTO Bitacora (IdUsuario, IdTipoOperacion, IP, FechaHora)
    VALUES (@IdUsuario, 2, @in_IP, GETDATE());
END;
GO