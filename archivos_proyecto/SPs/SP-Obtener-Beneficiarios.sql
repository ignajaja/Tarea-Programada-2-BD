CREATE OR ALTER PROCEDURE dbo.sp_ObtenerBeneficiarios
    @in_Username VARCHAR(64),          -- usuario que realiza la consulta
    @in_IdCuenta INT                   -- id de la cuenta cuyos beneficiarios se listan
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- obtener el id y privilegios del usuario actual
    DECLARE @IdUsuario INT;            -- id numérico del usuario
    DECLARE @EsAdmin BIT = 0;          -- privilegios de administrador
    
    SELECT @IdUsuario = Id, @EsAdmin = EsAdministrador 
    FROM Usuario 
    WHERE Username = @in_Username;

    -- obtener la lista de beneficiarios activos
    SELECT 
        b.Id AS beneficiarioid,
        c.NumeroCuenta AS numerocuenta,
        p.Nombre AS nombre,
        par.Nombre AS parentesco,
        b.Porcentaje AS porcentaje,
        td.Nombre AS tipodocumento,
        p.ValorDocumentoIdentidad AS valordocumento
    FROM Beneficiario b
    INNER JOIN Cuenta c ON b.IdCuenta = c.Id
    INNER JOIN Persona p ON b.IdPersonaBeneficiario = p.Id
    INNER JOIN Parentesco par ON b.IdParentesco = par.Id
    INNER JOIN Tipo_Doc td ON p.IdTipoDoc = td.Id
    WHERE b.IdCuenta = @in_IdCuenta 
      AND b.Activo = 1
      AND (@EsAdmin = 1 OR b.IdCuenta IN (
          SELECT IdCuenta 
          FROM Usuarios_Ver 
          WHERE IdUsuario = @IdUsuario
      ));
END;
GO