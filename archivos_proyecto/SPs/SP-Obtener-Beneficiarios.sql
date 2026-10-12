CREATE OR ALTER PROCEDURE dbo.sp_ObtenerBeneficiarios
    @in_Username VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Verificar si el usuario es admin para que pueda ver todos
    DECLARE @EsAdmin BIT = 0;
    SELECT @EsAdmin = EsAdministrador FROM Usuario WHERE Username = @in_Username;

    IF @EsAdmin = 1
    BEGIN
        -- Si es administrador, devuelve todos
        SELECT 
            Beneficiario.Id AS BeneficiarioId,
            Beneficiario.NumeroCuenta,
            Persona.Nombre,
            Parentesco.Nombre AS Parentesco,
            Beneficiario.Porcentaje,
            Tipo_Doc.Nombre AS TipoDocumento,
            Persona.ValorDocumentoIdentidad AS ValorDocumento
        FROM Beneficiario
        INNER JOIN Persona ON Beneficiario.ValorDocumentoIdentidadBeneficiario = Persona.ValorDocumentoIdentidad
        INNER JOIN Parentesco ON Beneficiario.ParentezcoId = Parentesco.Id
        INNER JOIN Tipo_Doc ON Persona.TipoDocuIdentidad = Tipo_Doc.Id
        WHERE Beneficiario.Activo = 1;
    END
    ELSE
    BEGIN
        -- Si no es admin, filtra los beneficiarios de su cuenta
        SELECT 
            Beneficiario.Id AS BeneficiarioId,
            Beneficiario.NumeroCuenta,
            Persona.Nombre,
            Parentesco.Nombre AS Parentesco,
            Beneficiario.Porcentaje,
            Tipo_Doc.Nombre AS TipoDocumento,
            Persona.ValorDocumentoIdentidad AS ValorDocumento
        FROM Beneficiario
        INNER JOIN Persona ON Beneficiario.ValorDocumentoIdentidadBeneficiario = Persona.ValorDocumentoIdentidad
        INNER JOIN Parentesco ON Beneficiario.ParentezcoId = Parentesco.Id
        INNER JOIN Tipo_Doc ON Persona.TipoDocuIdentidad = Tipo_Doc.Id
        INNER JOIN Cuenta ON Beneficiario.NumeroCuenta = Cuenta.NumeroCuenta
        INNER JOIN Usuarios_Ver ON Cuenta.NumeroCuenta = Usuarios_Ver.NumeroCuenta
        WHERE Usuarios_Ver.Username = @in_Username 
          AND Beneficiario.Activo = 1;
    END
END;