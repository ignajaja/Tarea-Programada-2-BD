USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_AgregarBeneficiario] Fecha de script: 11/19/2026 10:51:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_AgregarBeneficiario]
 @in_Username VARCHAR(64) -- usuario que realiza la accion
 , @in_NumeroCuenta VARCHAR(32) -- numero de la cuenta a la que se asocia el beneficiario
 , @in_TipoDoc INT -- id del tipo de documento del beneficiario
 , @in_NombrePersona VARCHAR(128) -- nombre completo del beneficiario
 , @in_ValorDoc VARCHAR(32) -- numero de documento del beneficiario
 , @in_FechaNac DATE -- fecha de nacimiento del beneficiario
 , @in_Email VARCHAR(128) -- email del beneficiario
 , @in_Tel1 VARCHAR(32) -- primer telefono del beneficiario
 , @in_Tel2 VARCHAR(32) -- segundo telefono del beneficiario
 , @in_IdParentesco INT -- id del parentesco con el dueño de la cuenta
 , @in_Porcentaje INT -- porcentaje asignado al beneficiario
 , @out_Codigo INT OUTPUT -- 0 exito, 1 limite de beneficiarios, 2 error de bd, 3 cuenta no pertenece al usuario, 4 ya es beneficiario, 5 usuario no existe, 6 porcentaje invalido, 7 la cuenta no existe
 , @out_Mensaje VARCHAR(256) OUTPUT -- mensaje del resultado
 , @in_IP VARCHAR(64) = '0.0.0.0' -- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
AS
/*
ejemplo de ejecucion
 DECLARE @codigo INT, @mensaje VARCHAR(256)
 EXEC dbo.sp_AgregarBeneficiario
  @in_Username = 'amora'
  , @in_NumeroCuenta = '11000001'
  , @in_TipoDoc = 1
  , @in_NombrePersona = 'Pedro Perez'
  , @in_ValorDoc = '123456789'
  , @in_FechaNac = '1990-01-01'
  , @in_Email = 'pedro@ejemplo.com'
  , @in_Tel1 = '88888888'
  , @in_Tel2 = '22222222'
  , @in_IdParentesco = 7
  , @in_Porcentaje = 10
  , @out_Codigo = @codigo OUTPUT
  , @out_Mensaje = @mensaje OUTPUT
  , @in_IP = '127.0.0.1'
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  DECLARE @IdUsuario INT; -- id del usuario que realiza la accion
  DECLARE @IdCuenta INT; -- id de la cuenta que corresponde al numero de cuenta recibido
  DECLARE @flagEsAdmin BIT = 0; -- 1 si el usuario es administrador
  DECLARE @flagTieneAcceso BIT = 0; -- 1 si el usuario puede modificar la cuenta
  DECLARE @CantidadActivos INT; -- beneficiarios activos que ya tiene la cuenta
  DECLARE @flagEsBeneficiarioActivo BIT = 0; -- 1 si la persona ya es beneficiaria activa de la cuenta
  DECLARE @flagPersonaExiste BIT = 0; -- 1 si la persona ya esta registrada en la tabla persona
  DECLARE @IdPersonaBeneficiario INT; -- id de la persona beneficiaria en la tabla persona
  DECLARE @NombreBeneficiario VARCHAR(128); -- nombre con que queda registrada la persona beneficiaria
  DECLARE @jsonNuevo VARCHAR(MAX); -- datos del nuevo beneficiario en json para la bitacora

  -- mapea el numero de cuenta a su id
  SELECT @IdCuenta = C.Id
  FROM dbo.Cuenta AS C
  WHERE C.NumeroCuenta = @in_NumeroCuenta;

  -- mapea el username al id y a los privilegios del usuario
  SELECT @IdUsuario = U.Id
   , @flagEsAdmin = U.EsAdministrador
  FROM dbo.Usuario AS U
  WHERE U.Username = @in_Username;

  -- el cliente solo puede modificar las cuentas que tiene asignadas
  SELECT @flagTieneAcceso = 1
  FROM dbo.Usuarios_Ver AS UV
  WHERE UV.IdUsuario = @IdUsuario
  AND UV.IdCuenta = @IdCuenta;

  -- el administrador puede modificar todas las cuentas
  IF (@flagEsAdmin = 1)
  BEGIN
   SET @flagTieneAcceso = 1;
  END;

  -- cuenta los beneficiarios activos de la cuenta
  SELECT @CantidadActivos = COUNT(*)
  FROM dbo.Beneficiario AS B
  WHERE B.IdCuenta = @IdCuenta
  AND B.Activo = 1;

  -- revisa si la persona ya es beneficiaria activa de esta cuenta
  SELECT @flagEsBeneficiarioActivo = 1
  FROM dbo.Beneficiario AS B
  INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
  WHERE B.IdCuenta = @IdCuenta
  AND B.Activo = 1
  AND P.ValorDocumentoIdentidad = @in_ValorDoc;

  -- revisa si la persona ya esta registrada, si lo esta se usa el nombre que tiene
  SELECT @flagPersonaExiste = 1
   , @NombreBeneficiario = P.Nombre
  FROM dbo.Persona AS P
  WHERE P.ValorDocumentoIdentidad = @in_ValorDoc;

  IF (@flagPersonaExiste = 0)
  BEGIN
   SET @NombreBeneficiario = @in_NombrePersona;
  END;

  -- determina el codigo y el mensaje con la primera validacion que falle
  SET @out_Codigo = 0;
  SET @out_Mensaje = 'Beneficiario agregado exitosamente';

  IF (@IdUsuario IS NULL)
  BEGIN
   SET @out_Codigo = 5;
   SET @out_Mensaje = 'El usuario no existe';
  END
  ELSE IF (@IdCuenta IS NULL)
  BEGIN
   SET @out_Codigo = 7;
   SET @out_Mensaje = 'La cuenta indicada no existe';
  END
  ELSE IF (@flagTieneAcceso = 0)
  BEGIN
   SET @out_Codigo = 3;
   SET @out_Mensaje = 'La cuenta indicada no pertenece al usuario';
  END
  ELSE IF (@in_Porcentaje IS NULL OR @in_Porcentaje <= 0 OR @in_Porcentaje > 100)
  BEGIN
   SET @out_Codigo = 6;
   SET @out_Mensaje = 'El porcentaje debe estar entre 1 y 100';
  END
  ELSE IF (@CantidadActivos >= 3)
  BEGIN
   SET @out_Codigo = 1;
   SET @out_Mensaje = 'La cuenta ya alcanzo el limite de beneficiarios';
  END
  ELSE IF (@flagEsBeneficiarioActivo = 1)
  BEGIN
   SET @out_Codigo = 4;
   SET @out_Mensaje = 'Esta persona ya es beneficiaria activa de la cuenta';
  END;

  -- si fallo alguna validacion se responde sin abrir la transaccion
  IF @out_Codigo > 0
  BEGIN
   SELECT @out_Codigo AS Codigo
    , @out_Mensaje AS Mensaje;
   RETURN;
  END;

  -- arma el json con los datos del beneficiario
  SET @jsonNuevo = '{"Nombre":"' + @NombreBeneficiario
   + '","Documento":"' + @in_ValorDoc
   + '","Porcentaje":' + CONVERT(VARCHAR(8), @in_Porcentaje) + '}';

  BEGIN TRANSACTION tAgregarBeneficiario;

  -- crea la persona solo si todavia no existe
  INSERT INTO dbo.Persona (
   IdTipoDoc
   , Nombre
   , ValorDocumentoIdentidad
   , FechaNacimiento
   , Email
   , telefono1
   , telefono2
  )
  SELECT @in_TipoDoc
   , @in_NombrePersona
   , @in_ValorDoc
   , @in_FechaNac
   , @in_Email
   , @in_Tel1
   , @in_Tel2
  WHERE @flagPersonaExiste = 0;

  -- mapea el documento al id de la persona
  SELECT @IdPersonaBeneficiario = P.Id
  FROM dbo.Persona AS P
  WHERE P.ValorDocumentoIdentidad = @in_ValorDoc;

  -- inserta el beneficiario ligado a la cuenta y a la persona por id
  INSERT INTO dbo.Beneficiario (
   IdParentesco
   , Porcentaje
   , Activo
   , FechaDesactivacion
   , IdCuenta
   , IdPersonaBeneficiario
  )
  VALUES (
   @in_IdParentesco
   , @in_Porcentaje
   , 1
   , NULL
   , @IdCuenta
   , @IdPersonaBeneficiario
  );

  -- registra en bitacora, tipo de operacion 3 agregar beneficiario
  INSERT INTO dbo.Bitacora (
   IdUsuario
   , IdTipoOperacion
   , JsonAntes
   , JsonDespues
   , IP
   , FechaHora
  )
  VALUES (
   @IdUsuario
   , 3
   , NULL
   , @jsonNuevo
   , @in_IP
   , GETDATE()
  );

  COMMIT TRANSACTION tAgregarBeneficiario;
 END TRY
 BEGIN CATCH
  -- ante un error se deshace todo, incluida la persona
  IF @@TRANCOUNT > 0
  BEGIN
   ROLLBACK TRANSACTION;
  END;
  SET @out_Codigo = 2;
  SET @out_Mensaje = ERROR_MESSAGE();
 END CATCH;

 -- devuelve el resultado final
 SELECT @out_Codigo AS Codigo
  , @out_Mensaje AS Mensaje;
END;
