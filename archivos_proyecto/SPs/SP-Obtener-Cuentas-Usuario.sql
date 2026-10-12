CREATE OR ALTER PROCEDURE dbo.sp_ObtenerCuentasUsuario
    @in_Username VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    -- Devuelve los números de cuenta a los que el usuario tiene acceso
    SELECT Cuenta.NumeroCuenta
    FROM Cuenta
    INNER JOIN Usuarios_Ver ON Cuenta.NumeroCuenta = Usuarios_Ver.NumeroCuenta
    WHERE Usuarios_Ver.Username = @in_Username
    ORDER BY Cuenta.NumeroCuenta
END;