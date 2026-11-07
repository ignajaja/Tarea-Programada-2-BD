CREATE OR ALTER PROCEDURE dbo.sp_ObtenerCuentasUsuario
    @in_Username VARCHAR(64)           -- usuario cuyas cuentas se consultan
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- consultar las cuentas que el usuario tiene permitido ver
    SELECT Cuenta.Id AS IdCuenta, Cuenta.NumeroCuenta
    FROM Cuenta
    INNER JOIN Usuarios_Ver ON Cuenta.Id = Usuarios_Ver.IdCuenta
    INNER JOIN Usuario ON Usuarios_Ver.IdUsuario = Usuario.Id
    WHERE Usuario.Username = @in_Username
    ORDER BY Cuenta.NumeroCuenta;
END;
GO