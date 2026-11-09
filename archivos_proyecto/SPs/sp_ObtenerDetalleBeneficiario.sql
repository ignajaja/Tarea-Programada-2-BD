CREATE OR ALTER PROCEDURE dbo.sp_ObtenerDetalleBeneficiario
 @in_Username VARCHAR(50), -- usuario que realiza la consulta
 @in_BeneficiarioId INT -- id del beneficiario a consultar
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ObtenerDetalleBeneficiario @in_Username = 'amora', @in_BeneficiarioId = 1
*/
BEGIN
 SET NOCOUNT ON;

 DECLARE @IdUsuario INT; -- id del usuario que consulta
 DECLARE @EsAdmin BIT = 0; -- 1 si el usuario es administrador

 -- mapea el username al id y a los privilegios del usuario
 SELECT @IdUsuario = U.Id, @EsAdmin = U.EsAdministrador
 FROM dbo.Usuario AS U
 WHERE U.Username = @in_Username;

 -- devuelve el detalle del beneficiario activo, solo si es administrador o su cuenta es del usuario
 SELECT
  B.Id AS beneficiarioid,
  C.NumeroCuenta AS numerocuenta,
  P.Id AS personaid,
  P.Nombre AS nombre,
  TD.Id AS tipodocumentoid,
  TD.Nombre AS tipodocumento,
  P.ValorDocumentoIdentidad AS valordocumento,
  P.FechaNacimiento AS fechanacimiento,
  P.Email AS email,
  P.telefono1 AS telefono1,
  P.telefono2 AS telefono2,
  PA.Id AS parentescoid,
  PA.Nombre AS parentesco,
  B.Porcentaje AS porcentaje
 FROM dbo.Beneficiario AS B
 INNER JOIN dbo.Cuenta AS C ON C.Id = B.IdCuenta
 INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
 INNER JOIN dbo.Parentesco AS PA ON PA.Id = B.IdParentesco
 INNER JOIN dbo.Tipo_Doc AS TD ON TD.Id = P.IdTipoDoc
 WHERE B.Id = @in_BeneficiarioId
 AND B.Activo = 1
 AND (
  @EsAdmin = 1
  OR EXISTS (
   SELECT 1
   FROM dbo.Usuarios_Ver AS UV
   WHERE UV.IdUsuario = @IdUsuario
   AND UV.IdCuenta = B.IdCuenta
  )
 );
END;
