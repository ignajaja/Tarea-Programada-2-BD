CREATE OR ALTER PROCEDURE dbo.sp_ConsultarEstadosDeCuenta
    @in_Username VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    -- Extraer los ultimos 8 estados de cuenta del usuario dado con todas sus métricas y el saldo mínimo
    SELECT TOP 8 
        Estado_Cuenta.NumeroCuenta,
        Estado_Cuenta.fechaInicio AS FechaInicio,
        Estado_Cuenta.fechafin AS FechaFin,
        Estado_Cuenta.saldoinicial AS SaldoInicial,
        Estado_Cuenta.saldoMinimo AS SaldoMinimo,
        Estado_Cuenta.saldo_final AS SaldoFinal,
        Estado_Cuenta.interesesAcumulados AS InteresesAcumulados,
        Estado_Cuenta.cantRetiros AS CantRetiros,
        Estado_Cuenta.cantDepositos AS CantDepositos,
        Estado_Cuenta.cantSinpeEntrantes AS CantSinpeEntrantes,
        Estado_Cuenta.cantSinpeSalientes AS CantSinpeSalientes
    FROM Estado_Cuenta
    INNER JOIN Cuenta ON Estado_Cuenta.NumeroCuenta = Cuenta.NumeroCuenta
    INNER JOIN Usuarios_Ver ON Cuenta.NumeroCuenta = Usuarios_Ver.NumeroCuenta
    WHERE Usuarios_Ver.Username = @in_Username
    ORDER BY Estado_Cuenta.fechafin DESC;

    -- Registrar en bitácora con tipo de operacion 7
    EXEC dbo.sp_RegistrarBitacora @in_Username = @in_Username, @in_IdTipoOperacion = 7;
END;