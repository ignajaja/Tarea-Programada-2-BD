CREATE OR ALTER PROCEDURE dbo.sp_CalcularPorcentajes
 @in_IdCuenta INT = NULL, -- id de la cuenta cuyos porcentajes se suman
 @in_BeneficiarioId INT = NULL -- alternativa, id de un beneficiario para ubicar su cuenta
AS
/*
ejemplo de ejecucion por cuenta
 EXEC dbo.sp_CalcularPorcentajes @in_IdCuenta = 1
ejemplo de ejecucion por beneficiario
 EXEC dbo.sp_CalcularPorcentajes @in_BeneficiarioId = 3
devuelve IdCuenta y SumaTotal, la aplicacion muestra la alerta cuando SumaTotal es menor que 100
*/
BEGIN
 SET NOCOUNT ON;

 DECLARE @IdCuenta INT; -- cuenta que se va a sumar

 -- usa la cuenta recibida, si no se recibio la busca a partir del beneficiario
 SELECT @IdCuenta = ISNULL(
  @in_IdCuenta,
  (SELECT B.IdCuenta FROM dbo.Beneficiario AS B WHERE B.Id = @in_BeneficiarioId)
 );

 -- suma solo los porcentajes de los beneficiarios activos de esa cuenta
 SELECT
  @IdCuenta AS IdCuenta,
  ISNULL(SUM(B.Porcentaje), 0) AS SumaTotal
 FROM dbo.Beneficiario AS B
 WHERE B.IdCuenta = @IdCuenta
 AND B.Activo = 1;
END;

