CREATE OR ALTER PROCEDURE dbo.sp_RegistrarLogout
    @in_Username VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    -- Registro en bitacora de cierre de sesion, con codigo de operacion 2
    EXEC dbo.sp_RegistrarBitacora 
        @in_Username = @in_Username, 
        @in_IdTipoOperacion = 2, 
        @in_JsonAntes = NULL, 
        @in_JsonDespues = NULL;
END;