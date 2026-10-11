CREATE OR ALTER PROCEDURE dbo.sp_IniciarSesion
    @in_Username VARCHAR(64),
    @in_Pass VARCHAR(128),
    @in_IP VARCHAR(64) = '0.0.0.0'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @out_EsAdministrador BIT = 0;
    DECLARE @out_CodigoRespuesta INT = 1;
    
    BEGIN TRY
        BEGIN TRANSACTION; 
        IF EXISTS (SELECT 1 FROM Usuario WHERE CAST(Username AS VARBINARY(64)) = CAST(@in_Username AS VARBINARY(64)) AND CAST(Pass AS VARBINARY(128)) = CAST(@in_Pass AS VARBINARY(128)))
        BEGIN 
            SELECT @out_EsAdministrador = EsAdministrador FROM Usuario WHERE CAST(Username AS VARBINARY(64)) = CAST(@in_Username AS VARBINARY(64)) AND CAST(Pass AS VARBINARY(128)) = CAST(@in_Pass AS VARBINARY(128));
            SET @out_CodigoRespuesta = 0;
            EXEC dbo.sp_RegistrarBitacora @in_Username = @in_Username, @in_IdTipoOperacion = 1, @in_IP = @in_IP;
        END
        ELSE
        BEGIN 
            SET @out_EsAdministrador = 0; 
            SET @out_CodigoRespuesta = 1;
        END
        COMMIT TRANSACTION; 
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @out_CodigoRespuesta = ERROR_NUMBER(); 
        SET @out_EsAdministrador = 0; 
    END CATCH
    SELECT @out_EsAdministrador AS EsAdministrador, @out_CodigoRespuesta AS CodigoRespuesta;
END;