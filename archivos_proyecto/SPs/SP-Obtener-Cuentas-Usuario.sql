CREATE OR ALTER PROCEDURE dbo.sp_ObtenerCuentasUsuario
    @in_Username VARCHAR(64)           -- usuario cuyas cuentas se consultan
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- obtener id y privilegios del usuario
    DECLARE @IdUsuario INT;            -- id numérico del usuario
    DECLARE @EsAdmin BIT = 0;          -- indicador de administrador

    SELECT @IdUsuario = Id, @EsAdmin = EsAdministrador 
    FROM Usuario 
    WHERE Username = @in_Username;

    -- si es administrador, retorna todas las cuentas del banco y si es usuario, solo las suyas
    IF @EsAdmin = 1
    BEGIN
        SELECT Id AS IdCuenta, NumeroCuenta
        FROM Cuenta
        ORDER BY NumeroCuenta;
    END
    ELSE
    BEGIN
        SELECT Cuenta.Id AS IdCuenta, Cuenta.NumeroCuenta
        FROM Cuenta
        INNER JOIN Usuarios_Ver ON Cuenta.Id = Usuarios_Ver.IdCuenta
        WHERE Usuarios_Ver.IdUsuario = @IdUsuario
        ORDER BY Cuenta.NumeroCuenta;
    END
END;
GO