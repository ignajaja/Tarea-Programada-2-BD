CREATE OR ALTER PROCEDURE dbo.sp_ObtenerBeneficiarios
    @in_Username VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
	
	--Se seleccionan id, parentezco, nombre, porcentaje, documento de identidad dado un usuario,
	--Devuelve los beneficiarios activos asociados.
    SELECT 
        Beneficiario.Id AS BeneficiarioId,
        Persona.Nombre,
        Parentesco.Nombre AS Parentesco,
        Beneficiario.Porcentaje,
        Tipo_Doc.Nombre AS TipoDocumento,
        Persona.ValorDocumentoIdentidad AS ValorDocumento
    FROM Beneficiario
    INNER JOIN Persona ON Beneficiario.ValorDocumentoIdentidadBeneficiario = Persona.ValorDocumentoIdentidad
    INNER JOIN Parentesco ON Beneficiario.ParentezcoId = Parentesco.Id
    INNER JOIN Tipo_Doc ON Persona.TipoDocuIdentidad = Tipo_Doc.Id
    INNER JOIN Cuentas ON Beneficiario.NumeroCuenta = Cuentas.NumeroCuenta
    INNER JOIN Usuarios_Ver ON Cuentas.NumeroCuenta = Usuarios_Ver.NumeroCuenta
    WHERE Usuarios_Ver.Username = @in_Username 
      AND Beneficiario.Activo = 1;
END;
