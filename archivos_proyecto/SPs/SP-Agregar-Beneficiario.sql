CREATE OR ALTER PROCEDURE dbo.sp_AgregarBeneficiario
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
    @out_Codigo INT OUTPUT, -- Se usa 0 para éxito al agregar, 1 para limite de usuarios alcanzados, 2 otros errores
    @out_Mensaje VARCHAR(256) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que no haya 3 beneficiarios
        IF (SELECT COUNT(*) FROM Beneficiario WHERE NumeroCuenta = @in_NumeroCuenta AND Activo = 1) >= 3 --Cuenta si son 3 o mas
        BEGIN
            SET @out_Codigo = 1; --Setea el codigo en 1
            SET @out_Mensaje = 'Error al agregar beneficiario: la cuenta ya alcanzó el límite de beneficiarios.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Verifica si el beneficiario existe en Persona, si no lo inserta
        IF NOT EXISTS (SELECT 1 FROM Persona WHERE ValorDocumentoIdentidad = @in_ValorDoc)
        BEGIN
            INSERT INTO Persona (TipoDocuIdentidad, Nombre, ValorDocumentoIdentidad, FechaNacimiento, Email, telefono1, telefono2)
            VALUES (@in_TipoDoc, @in_NombrePersona, @in_ValorDoc, @in_FechaNac, @in_Email, @in_Tel1, @in_Tel2);
        END

        -- Inserta en beneficiario
        INSERT INTO Beneficiario (NumeroCuenta, ValorDocumentoIdentidadBeneficiario, ParentezcoId, Porcentaje, Activo)
        VALUES (@in_NumeroCuenta, @in_ValorDoc, @in_IdParentezco, @in_Porcentaje, 1);

        -- Se genera el json para la bitacora
        DECLARE @jsonNuevo VARCHAR(MAX);
        SET @jsonNuevo = (
            SELECT Nombre, ValorDocumentoIdentidad AS Documento, @in_Porcentaje AS Porcentaje 
            FROM Persona WHERE ValorDocumentoIdentidad = @in_ValorDoc 
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        -- Se registra en la bitacora el cambio, tipo operacion 3 corresponde a agregar beneficiario
        EXEC dbo.sp_RegistrarBitacora @in_Username = @in_Username, @in_IdTipoOperacion = 3, @in_JsonAntes = NULL, @in_JsonDespues = @jsonNuevo;

        COMMIT TRANSACTION;
        SET @out_Codigo = 0; --Si todo sale bien codigo 0 de exito
        SET @out_Mensaje = 'Beneficiario agregado exitosamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @out_Codigo = 2;
        SET @out_Mensaje = ERROR_MESSAGE();
    END CATCH
END;