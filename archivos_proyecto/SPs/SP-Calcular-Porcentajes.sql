CREATE OR ALTER PROCEDURE dbo.sp_CalcularPorcentajes
    @in_BeneficiarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @NumeroCuenta INT;
    SELECT @NumeroCuenta = NumeroCuenta FROM Beneficiario WHERE Id = @in_BeneficiarioId;
    
    DECLARE @SumaPorcentajes INT;
    SELECT @SumaPorcentajes = ISNULL(SUM(Porcentaje), 0)
    FROM Beneficiario
    WHERE NumeroCuenta = @NumeroCuenta AND Activo = 1;
    
    -- Retorna la suma total de esa cuenta y la cuenta donde no se cumple
    SELECT @NumeroCuenta AS NumeroCuenta, @SumaPorcentajes AS SumaTotal;
END;