CREATE OR ALTER PROCEDURE dbo.sp_EliminarBeneficiario
    @in_Username VARCHAR(64),
    @in_BeneficiarioId INT,
    @out_Codigo INT OUTPUT,
    @out_Mensaje VARCHAR(256) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        --- Se guarda el json antes de realizar el cambio
        DECLARE @jsonAntes VARCHAR(MAX);
		SET @jsonAntes = (
			SELECT 
				Beneficiario.Id, 
				Beneficiario.Activo, 
				Beneficiario.FechaDesactivacion 
			FROM Beneficiario 
			WHERE Beneficiario.Id = @in_BeneficiarioId
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		);


        --Se cambia el estado de activo a inactivo y almacena fecha
        UPDATE Beneficiario 
        SET Activo = 0, FechaDesactivacion = GETDATE() 
        WHERE Id = @in_BeneficiarioId;

        -- Se guarda el json luego de realizar el cambio
        DECLARE @jsonDespues VARCHAR(MAX);
		SET @jsonDespues = (
			SELECT 
				Beneficiario.Id, 
				Beneficiario.Activo, 
				Beneficiario.FechaDesactivacion 
			FROM Beneficiario 
			WHERE Beneficiario.Id = @in_BeneficiarioId
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		);

        --En la bitacora se registra con operacion 5 que corresponde a eliminar beneficiario
        EXEC dbo.sp_RegistrarBitacora @in_Username = @in_Username, @in_IdTipoOperacion = 5, @in_JsonAntes = @jsonAntes, @in_JsonDespues = @jsonDespues;

        COMMIT TRANSACTION;
        SET @out_Codigo = 0;
        SET @out_Mensaje = 'El beneficiario se ha desligado de su cuenta exitosamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @out_Codigo = 1;
        SET @out_Mensaje = ERROR_MESSAGE();
    END CATCH
END;