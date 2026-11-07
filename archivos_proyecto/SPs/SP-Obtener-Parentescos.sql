CREATE OR ALTER PROCEDURE dbo.sp_ObtenerParentescos
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- consultar todos los parentescos ordenados por id
    SELECT Id, Nombre 
    FROM Parentesco 
    ORDER BY Id;
END;
GO