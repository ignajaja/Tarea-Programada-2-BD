CREATE OR ALTER PROCEDURE dbo.sp_ObtenerParentescos
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ObtenerParentescos
*/
BEGIN
 SET NOCOUNT ON;

 -- lista todos los parentescos ordenados por id
 SELECT P.Id, P.Nombre
 FROM dbo.Parentesco AS P
 ORDER BY P.Id;
END;
