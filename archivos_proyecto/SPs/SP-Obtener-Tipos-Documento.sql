CREATE OR ALTER PROCEDURE dbo.sp_ObtenerTiposDocumento
AS
BEGIN 
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- consultar todos los tipos de documento ordenados por id
    SELECT Id, Nombre 
    FROM Tipo_Doc 
    ORDER BY Id;
END;
GO