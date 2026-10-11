CREATE OR ALTER PROCEDURE dbo.sp_RegistrarBitacora
    @in_Username VARCHAR(64),
    @in_IdTipoOperacion INT,
    @in_JsonAntes VARCHAR(MAX) = NULL,
    @in_JsonDespues VARCHAR(MAX) = NULL,
    @in_IP VARCHAR(64) = '0.0.0.0'
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Bitacora (Username, IdTipoOperacion, JsonAntes, JsonDespues, IP, FechaHora)
    VALUES (@in_Username, @in_IdTipoOperacion, @in_JsonAntes, @in_JsonDespues, @in_IP, GETDATE());
END;