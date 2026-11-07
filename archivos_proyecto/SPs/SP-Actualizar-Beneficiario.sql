CREATE OR ALTER PROCEDURE dbo.sp_ActualizarBeneficiario
    @in_Username VARCHAR(64),          -- usuario que realiza la actualización
    @in_BeneficiarioId INT,            -- id del registro de beneficiario a modificar
    @in_NombrePersona VARCHAR(64),     -- nuevo nombre de la persona
    @in_IdParentesco INT,              -- nuevo id de parentesco
    @in_Porcentaje INT,                -- nuevo porcentaje asignado
    @in_IP VARCHAR(64) = '0.0.0.0'     -- ip por defecto si no se recibe desde views.py
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- inicializar código de salida exitoso por defecto
    DECLARE @out_Codigo INT = 0; 
    DECLARE @out_Mensaje VARCHAR(256) = 'Beneficiario actualizado correctamente.';

    -- obtener el id del usuario que va a actualizar
    DECLARE @IdUsuario INT;            -- id numérico del usuario
    SELECT @IdUsuario = Id 
    FROM Usuario 
    WHERE Username = @in_Username;
    
    -- intentar la actualización de datos
    BEGIN TRY
        -- generar el json con los datos del beneficiario antes del cambio
        DECLARE @jsonAntes VARCHAR(MAX); -- almacena el estado previo en json
        SET @jsonAntes = (
            SELECT p.Nombre, par.Nombre AS Parentesco, b.Porcentaje 
            FROM Beneficiario b
            INNER JOIN Persona p ON b.IdPersonaBeneficiario = p.Id
            INNER JOIN Parentesco par ON b.IdParentesco = par.Id
            WHERE b.Id = @in_BeneficiarioId
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        -- obtener el id de la persona ligada al beneficiario
        DECLARE @IdPersonaBeneficiario INT; -- id numérico de la persona
        SELECT @IdPersonaBeneficiario = IdPersonaBeneficiario 
        FROM Beneficiario 
        WHERE Id = @in_BeneficiarioId;

        BEGIN TRANSACTION;
            -- actualizar el nombre en la tabla persona
            UPDATE Persona 
            SET Nombre = @in_NombrePersona 
            WHERE Id = @IdPersonaBeneficiario;
            
            -- actualizar el parentesco y porcentaje en la tabla beneficiario
            UPDATE Beneficiario 
            SET IdParentesco = @in_IdParentesco, 
                Porcentaje = @in_Porcentaje 
            WHERE Id = @in_BeneficiarioId;

            -- generar el json con los datos del beneficiario después del cambio
            DECLARE @jsonDespues VARCHAR(MAX); -- almacena el estado posterior en json
            SET @jsonDespues = (
                SELECT p.Nombre, par.Nombre AS Parentesco, b.Porcentaje 
                FROM Beneficiario b
                INNER JOIN Persona p ON b.IdPersonaBeneficiario = p.Id
                INNER JOIN Parentesco par ON b.IdParentesco = par.Id
                WHERE b.Id = @in_BeneficiarioId
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

            -- registrar la actualización en la bitácora (tipo de operación 4)
            INSERT INTO Bitacora (
                IdUsuario, IdTipoOperacion, 
                JsonAntes, JsonDespues, IP, FechaHora
            )
            VALUES (
                @IdUsuario, 4, 
                @jsonAntes, @jsonDespues, @in_IP, GETDATE()
            );
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- si ocurre un error deshace los cambios
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @out_Codigo = 2;
        SET @out_Mensaje = ERROR_MESSAGE();
    END CATCH
    
    -- retornar el código y mensaje final
    SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
END;
GO