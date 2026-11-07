CREATE OR ALTER PROCEDURE dbo.sp_ObtenerDetalleBeneficiario
    @in_BeneficiarioId INT             -- ID del beneficiario a consultar
AS
BEGIN
    SET NOCOUNT ON;

    -- Consultar los datos del beneficiario y su persona asociada usando IDs
    SELECT 
        b.Id AS beneficiarioid,
        c.NumeroCuenta AS numerocuenta,
        p.Id AS personaid,
        p.Nombre AS nombre,
        td.Id AS tipodocumentoid,
        td.Nombre AS tipodocumento,
        p.ValorDocumentoIdentidad AS valordocumento,
        p.FechaNacimiento AS fechanacimiento,
        p.Email AS email,
        p.telefono1 AS telefono1,
        p.telefono2 AS telefono2,
        par.Id AS parentescoid,
        par.Nombre AS parentesco,
        b.Porcentaje AS porcentaje
    FROM Beneficiario b
    INNER JOIN Cuenta c ON b.IdCuenta = c.Id
    INNER JOIN Persona p ON b.IdPersonaBeneficiario = p.Id
    INNER JOIN Parentesco par ON b.IdParentesco = par.Id
    INNER JOIN Tipo_Doc td ON p.IdTipoDoc = td.Id
    WHERE b.Id = @in_BeneficiarioId 
      AND b.Activo = 1;
END;
GO