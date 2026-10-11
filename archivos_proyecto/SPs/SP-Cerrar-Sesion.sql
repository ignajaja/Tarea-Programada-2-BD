CREATE OR ALTER PROCEDURE dbo.sp_CerrarSesion
	@in_Username VARCHAR(64),
    @in_IP VARCHAR(64) = '0.0.0.0'
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_RegistrarBitacora @in_Username = @in_Username, @in_IdTipoOperacion = 2, @in_IP = @in_IP;
END;