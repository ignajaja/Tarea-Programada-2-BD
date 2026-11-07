CREATE OR ALTER PROCEDURE dbo.sp_CalcularPorcentajes
    @in_BeneficiarioId INT             -- id del beneficiario para ubicar su cuenta
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas
    
    -- obtener el id de la cuenta asociada al beneficiario
    DECLARE @IdCuenta INT;             -- id numérico de la cuenta
    SELECT @IdCuenta = IdCuenta 
    FROM Beneficiario 
    WHERE Id = @in_BeneficiarioId;
    
    -- calcular la suma total de los porcentajes activos de esa cuenta 
    DECLARE @SumaPorcentajes INT;      -- acumula el porcentaje total
    SELECT @SumaPorcentajes = ISNULL(SUM(Porcentaje), 0)
    FROM Beneficiario
    WHERE IdCuenta = @IdCuenta 
      AND Activo = 1;
    
    -- retornar la cuenta y la suma total obtenida
    SELECT @IdCuenta AS IdCuenta, @SumaPorcentajes AS SumaTotal;
END;
GO