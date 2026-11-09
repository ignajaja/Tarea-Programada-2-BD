
-- no pueden haber validaciones 
-- las tranascciones no pueden ser modulares 



CREATE OR ALTER PROCEDURE dbo.sp_AgregarBeneficiario
-- hacer las variables banderas para el rollback

    @in_Username VARCHAR(64),
    @in_NumeroCuenta INT,
    @in_TipoDoc INT,
    @in_NombrePersona VARCHAR(64),
    @in_ValorDoc VARCHAR(32),
    @in_FechaNac DATE,
    @in_Email VARCHAR(256),
    @in_Tel1 VARCHAR(16),
    @in_Tel2 VARCHAR(16),
    @in_IdParentezco INT,
    @in_Porcentaje INT,
    @in_PersonaExiste INT, -- hay que cambiar las validaciones
    @in_IP VARCHAR(64) = '0.0.0.0'

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nuevoIdBeneficiario INT;
    DECLARE @nuevoIdBitacora INT;
    DECLARE @personaInsertada INT = 0;
    DECLARE @beneficiarioInsertado INT = 0;
    DECLARE @bitacoraActulizada INT = 0;
    DECLARE @jsonNuevo VARCHAR(MAX);

    DECLARE @out_Codigo INT = 2;
    DECLARE @out_Mensaje VARCHAR(256) = '';

    BEGIN TRY

        BEGIN TRANSACTION;

        IF (@in_PersonaExiste = 0)
        BEGIN
            INSERT INTO Persona(TipoDocuIdentidad, Nombre, ValorDocumentoIdentidad, FechaNacimiento, Email, telefono1, telefono2)
            VALUES (@in_TipoDoc, @in_NombrePersona, @in_ValorDoc, @in_FechaNac, @in_Email, @in_Tel1, @in_Tel2);
            SET @personaInsertada = 1;
        END

        INSERT INTO Beneficiario (NumeroCuenta, ValorDocumentoIdentidadBeneficiario, ParentezcoId, Porcentaje, Activo)
        VALUES (@in_NumeroCuenta, @in_ValorDoc, @in_IdParentezco, @in_Porcentaje, 1);
-- PREGUNTAR: si se puede usar SCOPE_IDENTITY() ???
        SET @nuevoIdBeneficiario = SCOPE_IDENTITY();
        SET @beneficiarioInsertado = 1;

        SET @jsonNuevo = (
            SELECT Nombre, ValorDocumentoIdentidad AS Documento, @in_Porcentaje AS Porcentaje
            FROM Persona WHERE ValorDocumentoIdentidad = @in_ValorDoc
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );


        INSERT INTO Bitacora (Username, IdTipoOperacion, JsonAntes, JsonDespues, IP, FechaHora)
        VALUES (@in_Username, 3, NULL, @jsonNuevo, @in_IP, GETDATE());
        SET @nuevoIdBitacora = SCOPE_IDENTITY();
        SET @bitacoraActulizada = 1; 

        COMMIT TRANSACTION;
        SET @out_Codigo = 0;
        SET @out_Mensaje = 'Beneficiario agregado de manera exitosa';
     
    END TRY

    BEGIN CATCH
        
        IF @bitacoraActulizada = 1
            DELETE FROM Bitacora WHERE Id = @nuevoIdBitacora;

        IF @beneficiarioInsertado = 1
            DELETE FROM Beneficiario WHERE Id = @nuevoIdBeneficiario;


        IF @personaInsertada = 1 
            DELETE FROM Persona WHERE ValorDocumentoIdentidad = @in_ValorDoc;
            

        COMMIT TRANSACTION;

        SET @out_Codigo = 2;
        SET @out_Mensaje = 'No se pudo insertar a el beneficiarios';

    END CATCH
    SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;

END;

