CREATE OR ALTER PROCEDURE dbo.sp_ObtenerTiposDocumento
AS
BEGIN 
    SET NOCOUNT ON;
    SELECT Id, Nombre FROM Tipo_Doc ORDER BY Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerParentescos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Nombre FROM Parentesco ORDER BY Id;
END;
GO