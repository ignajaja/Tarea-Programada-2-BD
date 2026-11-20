USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_ObtenerBeneficiarios] Fecha de script: 11/19/2026 11:01:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_ObtenerBeneficiarios]
 @in_Username VARCHAR(64) -- usuario que realiza la consulta
 , @in_IdCuenta INT -- id de la cuenta cuyos beneficiarios se listan
 , @out_ResultCode INT = 0 OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ObtenerBeneficiarios @in_Username = 'amora', @in_IdCuenta = 1
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  DECLARE @IdUsuario INT; -- id del usuario que consulta
  DECLARE @flagEsAdmin BIT = 0; -- 1 si el usuario es administrador
  DECLARE @flagTieneAcceso BIT = 0; -- 1 si el usuario puede ver la cuenta
  DECLARE @NumeroCuenta VARCHAR(32); -- numero de la cuenta consultada

  -- mapea el username al id y a los privilegios del usuario
  SELECT @IdUsuario = U.Id
   , @flagEsAdmin = U.EsAdministrador
  FROM dbo.Usuario AS U
  WHERE U.Username = @in_Username;

  -- el cliente solo puede ver las cuentas que tiene asignadas
  SELECT @flagTieneAcceso = 1
  FROM dbo.Usuarios_Ver AS UV
  WHERE UV.IdUsuario = @IdUsuario
  AND UV.IdCuenta = @in_IdCuenta;

  -- el administrador puede ver todas las cuentas
  IF (@flagEsAdmin = 1)
  BEGIN
   SET @flagTieneAcceso = 1;
  END;

  -- numero de la cuenta que se muestra en cada fila
  SELECT @NumeroCuenta = C.NumeroCuenta
  FROM dbo.Cuenta AS C
  WHERE C.Id = @in_IdCuenta;

  -- lista los beneficiarios activos de la cuenta, solo si es administrador o la cuenta es del usuario
  SELECT
   B.Id AS beneficiarioid
   , @NumeroCuenta AS numerocuenta
   , P.Nombre AS nombre
   , PA.Nombre AS parentesco
   , B.Porcentaje AS porcentaje
   , TD.Nombre AS tipodocumento
   , P.ValorDocumentoIdentidad AS valordocumento
  FROM dbo.Beneficiario AS B
  INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
  INNER JOIN dbo.Parentesco AS PA ON PA.Id = B.IdParentesco
  INNER JOIN dbo.Tipo_Doc AS TD ON TD.Id = P.IdTipoDoc
  WHERE B.IdCuenta = @in_IdCuenta
  AND B.Activo = 1
  AND @flagTieneAcceso = 1;
 END TRY
 BEGIN CATCH
  SET @out_ResultCode = 50000;
 END CATCH;
END;
