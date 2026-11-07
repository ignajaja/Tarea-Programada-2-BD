CREATE OR ALTER PROCEDURE dbo.sp_IniciarSesion
    @in_Username VARCHAR(64),          -- usuario que intenta iniciar sesión
    @in_Pass VARCHAR(64),              -- contraseña de acceso
    @in_IP VARCHAR(64) = '0.0.0.0'     -- ip por defecto si no se recibe desde views.py
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- inicializar variables de control de sesión
    DECLARE @IdUsuario INT;            -- id numérico del usuario
    DECLARE @EsAdmin BIT = 0;          -- indicador de privilegios
    DECLARE @Codigo INT = 1;           -- 1 por defecto (error o credenciales inválidas)

    -- validar las credenciales del usuario
    SELECT @IdUsuario = Id, @EsAdmin = EsAdministrador
    FROM Usuario
    WHERE Username = @in_Username 
      AND Pass = @in_Pass;

    -- si el usuario existe, el inicio es exitoso
    IF @IdUsuario IS NOT NULL
    BEGIN
        SET @Codigo = 0;

        -- registrar el inicio de sesión en la bitácora (tipo de operación 1)
        INSERT INTO Bitacora (IdUsuario, IdTipoOperacion, IP, FechaHora)
        VALUES (@IdUsuario, 1, @in_IP, GETDATE());
    END

    -- retornar si es administrador y el código de resultado
    SELECT @EsAdmin AS EsAdmin, @Codigo AS Codigo;
END;
GO