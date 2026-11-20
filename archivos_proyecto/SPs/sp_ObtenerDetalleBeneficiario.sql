USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_ObtenerDetalleBeneficiario] Fecha de script: 11/19/2026 11:02:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_ObtenerDetalleBeneficiario]
 @in_Username VARCHAR(64) -- usuario que realiza la consulta
 , @in_BeneficiarioId INT -- id del beneficiario a consultar
 , @out_ResultCode INT = 0 OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ObtenerDetalleBeneficiario @in_Username = 'amora', @in_BeneficiarioId = 1
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  DECLARE @IdUsuario INT; -- id del usuario que consulta
  DECLARE @flagEsAdmin BIT = 0; -- 1 si el usuario es administrador
  DECLARE @flagTieneAcceso BIT = 0; -- 1 si el usuario puede ver la cuenta del beneficiario
  DECLARE @IdCuenta INT; -- id de la cuenta del beneficiario
  DECLARE @NumeroCuenta VARCHAR(32); -- numero de la cuenta del beneficiario

  -- mapea el username al id y a los privilegios del usuario
  SELECT @IdUsuario = U.Id
   , @flagEsAdmin = U.EsAdministrador
  FROM dbo.Usuario AS U
  WHERE U.Username = @in_Username;

  -- busca la cuenta a la que pertenece el beneficiario
  SELECT @IdCuenta = C.Id
   , @NumeroCuenta = C.NumeroCuenta
  FROM dbo.Beneficiario AS B
  INNER JOIN dbo.Cuenta AS C ON C.Id = B.IdCuenta
  WHERE B.Id = @in_BeneficiarioId;

  -- el cliente solo puede ver las cuentas que tiene asignadas
  SELECT @flagTieneAcceso = 1
  FROM dbo.Usuarios_Ver AS UV
  WHERE UV.IdUsuario = @IdUsuario
  AND UV.IdCuenta = @IdCuenta;

  -- el administrador puede ver todas las cuentas
  IF (@flagEsAdmin = 1)
  BEGIN
   SET @flagTieneAcceso = 1;
  END;

  -- devuelve el detalle del beneficiario activo, solo si es administrador o su cuenta es del usuario
  SELECT
   B.Id AS beneficiarioid
   , @NumeroCuenta AS numerocuenta
   , P.Id AS personaid
   , P.Nombre AS nombre
   , TD.Id AS tipodocumentoid
   , TD.Nombre AS tipodocumento
   , P.ValorDocumentoIdentidad AS valordocumento
   , P.FechaNacimiento AS fechanacimiento
   , P.Email AS email
   , P.telefono1 AS telefono1
   , P.telefono2 AS telefono2
   , PA.Id AS parentescoid
   , PA.Nombre AS parentesco
   , B.Porcentaje AS porcentaje
  FROM dbo.Beneficiario AS B
  INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
  INNER JOIN dbo.Parentesco AS PA ON PA.Id = B.IdParentesco
  INNER JOIN dbo.Tipo_Doc AS TD ON TD.Id = P.IdTipoDoc
  WHERE B.Id = @in_BeneficiarioId
  AND B.Activo = 1
  AND @flagTieneAcceso = 1;
 END TRY
 BEGIN CATCH
  SET @out_ResultCode = 50000;
 END CATCH;
END;
