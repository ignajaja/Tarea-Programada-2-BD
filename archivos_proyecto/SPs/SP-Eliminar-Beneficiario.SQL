CREATE OR ALTER PROCEDURE dbo.sp_EliminarBeneficiario
    @in_Username VARCHAR(64),          -- usuario que realiza la eliminación
    @in_BeneficiarioId INT,            -- id del beneficiario a eliminar
    @in_IP VARCHAR(64) = '0.0.0.0'     -- ip por defecto si no se recibe desde views.py
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- inicializar variables de respuesta por defecto
    DECLARE @Codigo INT = 0;
    DECLARE @Mensaje VARCHAR(256) = 'Beneficiario eliminado correctamente.';

    -- obtener el id del usuario que elimina
    DECLARE @IdUsuario INT;            -- id numérico del usuario
    SELECT @IdUsuario = Id 
    FROM Usuario 
    WHERE Username = @in_Username;

    -- verificar que el beneficiario exista y esté activo
    IF NOT EXISTS (
        SELECT 1 
        FROM Beneficiario 
        WHERE Id = @in_BeneficiarioId 
          AND Activo = 1
    )
    BEGIN
        SET @Codigo = 1;
        SET @Mensaje = 'El beneficiario no existe o ya está inactivo.';
        SELECT @Codigo AS Codigo, @Mensaje AS Mensaje;
        RETURN;
    END

    -- intentar la eliminación lógica
    BEGIN TRY
        -- generar el json con los datos del beneficiario antes de eliminar
        DECLARE @jsonAntes VARCHAR(MAX); -- almacena los datos previos en json
        SET @jsonAntes = (
            SELECT p.Nombre, par.Nombre AS Parentesco, b.Porcentaje 
            FROM Beneficiario b
            INNER JOIN Persona p ON b.IdPersonaBeneficiario = p.Id
            INNER JOIN Parentesco par ON b.IdParentesco = par.Id
            WHERE b.Id = @in_BeneficiarioId
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        BEGIN TRANSACTION;
            -- realizar la eliminación lógica
            UPDATE Beneficiario 
            SET Activo = 0, 
                FechaDesactivacion = GETDATE() 
            WHERE Id = @in_BeneficiarioId;

            -- registrar la eliminación en la bitácora (tipo de operación 5)
            INSERT INTO Bitacora (
                IdUsuario, IdTipoOperacion, 
                JsonAntes, IP, FechaHora
            )
            VALUES (
                @IdUsuario, 5, 
                @jsonAntes, @in_IP, GETDATE()
            );
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- si ocurre un error deshace la transacción
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Codigo = 1;
        SET @Mensaje = ERROR_MESSAGE();
    END CATCH;

    -- retornar el código y mensaje final
    SELECT @Codigo AS Codigo, @Mensaje AS Mensaje;
END;
GO