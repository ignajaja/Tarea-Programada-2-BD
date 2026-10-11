CREATE OR ALTER PROCEDURE dbo.sp_ActualizarBeneficiario
    @in_Username VARCHAR(64),
    @in_BeneficiarioId INT,
    @in_NombrePersona VARCHAR(64),
    @in_IdParentezco INT,
    @in_Porcentaje INT,
    @out_Codigo INT OUTPUT, --0 para exito 1 para cualquier otro
    @out_Mensaje VARCHAR(256) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Se guarda el json antes de realizar el cambio
        DECLARE @jsonAntes VARCHAR(MAX);
		SET @jsonAntes = (
			SELECT 
				Persona.Nombre, 
				Parentesco.Nombre AS Parentesco, 
				Beneficiario.Porcentaje 
			FROM Beneficiario 
			INNER JOIN Persona ON Beneficiario.ValorDocumentoIdentidadBeneficiario = Persona.ValorDocumentoIdentidad
			INNER JOIN Parentesco ON Beneficiario.ParentezcoId = Parentesco.Id
			WHERE Beneficiario.Id = @in_BeneficiarioId
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		);


        --Se busca el valor del documento de identidad de la persona para almacenarlo en variable
        DECLARE @docPersona VARCHAR(32); 
        SELECT @docPersona = ValorDocumentoIdentidadBeneficiario FROM Beneficiario WHERE Id = @in_BeneficiarioId;

        --Actualizar datos en Persona y Beneficiario
        UPDATE Persona SET Nombre = @in_NombrePersona WHERE ValorDocumentoIdentidad = @docPersona;
        UPDATE Beneficiario SET ParentezcoId = @in_IdParentezco, Porcentaje = @in_Porcentaje WHERE Id = @in_BeneficiarioId;

		--Json despues de modificar
		DECLARE @jsonDespues VARCHAR(MAX);
		SET @jsonDespues = (
			SELECT 
				Persona.Nombre, 
				Parentesco.Nombre AS Parentesco, 
				Beneficiario.Porcentaje 
			FROM Beneficiario 
			INNER JOIN Persona ON Beneficiario.ValorDocumentoIdentidadBeneficiario = Persona.ValorDocumentoIdentidad
			INNER JOIN Parentesco ON Beneficiario.ParentezcoId = Parentesco.Id
			WHERE Beneficiario.Id = @in_BeneficiarioId
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		);

        -- Se registra el cambio en la bitacora con tipo de operacion 4 que corresponde a actualizar un beneficiario
        EXEC dbo.sp_RegistrarBitacora @in_Username = @in_Username, @in_IdTipoOperacion = 4, @in_JsonAntes = @jsonAntes, @in_JsonDespues = @jsonDespues;

        COMMIT TRANSACTION;
        SET @out_Codigo = 0;
        SET @out_Mensaje = 'Beneficiario actualizado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @out_Codigo = 1;
        SET @out_Mensaje = ERROR_MESSAGE();
    END CATCH
END;