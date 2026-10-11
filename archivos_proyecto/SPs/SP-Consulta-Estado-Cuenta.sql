CREATE OR ALTER PROCEDURE dbo.sp_ConsultarEstadosDeCuenta
    @in_Username VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    -- Extraer los ultimos 8 estados de cuenta del usuario dado
    SELECT TOP 8 
        Estado_de_Cuenta.NumeroCuenta,
        Estado_de_Cuenta.fechaInicio AS FechaInicio,
        Estado_de_Cuenta.fechafin AS FechaFin,
        Estado_de_Cuenta.saldoinicial AS SaldoInicial,
        Estado_de_Cuenta.saldoMinimo AS SaldoMinimo,
        Estado_de_Cuenta.saldo_final AS SaldoFinal
    FROM Estado_de_Cuenta
    INNER JOIN Cuentas ON Estado_de_Cuenta.NumeroCuenta = Cuentas.NumeroCuenta
    INNER JOIN Usuarios_Ver ON Cuentas.NumeroCuenta = Usuarios_Ver.NumeroCuenta
    WHERE Usuarios_Ver.Username = @in_Username
    ORDER BY Estado_de_Cuenta.fechafin DESC;

    -- Registrar en bitácora con tipo de operacion 7
    EXEC dbo.sp_RegistrarBitacora @in_Username = @in_Username, @in_IdTipoOperacion = 7;
END;