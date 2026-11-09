CREATE OR ALTER PROCEDURE dbo.sp_ObtenerTiposDocumento
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ObtenerTiposDocumento
*/
BEGIN
 SET NOCOUNT ON;

 -- lista todos los tipos de documento ordenados por id
 SELECT TD.Id, TD.Nombre
 FROM dbo.Tipo_Doc AS TD
 ORDER BY TD.Id;
END;
