CREATE OR ALTER PROCEDURE dbo.sp_AgregarBeneficiario
 @in_Username VARCHAR(50), -- usuario que realiza la accion
 @in_NumeroCuenta VARCHAR(20), -- numero de cuenta a la que se asociara el beneficiario
 @in_TipoDoc INT, -- id del tipo de documento del beneficiario
 @in_NombrePersona VARCHAR(100), -- nombre completo del beneficiario
 @in_ValorDoc VARCHAR(20), -- numero de documento del beneficiario
 @in_FechaNac DATE, -- fecha de nacimiento del beneficiario
 @in_Email VARCHAR(100), -- email del beneficiario
 @in_Tel1 VARCHAR(20), -- primer telefono del beneficiario
 @in_Tel2 VARCHAR(20), -- segundo telefono del beneficiario
 @in_IdParentesco INT, -- id del parentesco con el dueño de la cuenta
 @in_Porcentaje INT, -- porcentaje asignado al beneficiario
 @out_Codigo INT OUTPUT, -- 0 exito, 1 limite de beneficiarios, 2 error de bd, 3 cuenta no pertenece al usuario, 4 ya es beneficiario, 5 usuario no existe, 6 porcentaje invalido
 @out_Mensaje VARCHAR(256) OUTPUT, -- mensaje del resultado
 @in_IP VARCHAR(50) = '0.0.0.0' -- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
AS
/*
ejemplo de ejecucion
 DECLARE @codigo INT, @mensaje VARCHAR(256)
 EXEC dbo.sp_AgregarBeneficiario
  @in_Username = 'amora',
  @in_IdCuenta = 1,
  @in_TipoDoc = 1,
  @in_NombrePersona = 'Pedro Perez',
  @in_ValorDoc = '123456789',
  @in_FechaNac = '1990-01-01',
  @in_Email = 'pedro@ejemplo.com',
  @in_Tel1 = '88888888',
  @in_Tel2 = '22222222',
  @in_IdParentesco = 7,
  @in_Porcentaje = 10,
  @out_Codigo = @codigo OUTPUT,
  @out_Mensaje = @mensaje OUTPUT,
  @in_IP = '127.0.0.1'
*/
BEGIN
 SET NOCOUNT ON;

 DECLARE @IdUsuario INT; -- id del usuario que realiza la accion
 DECLARE @EsAdmin BIT = 0; -- 1 si el usuario es administrador
 DECLARE @IdCuenta INT; --almacena el ID de la cuenta
 DECLARE @CantidadActivos INT; -- beneficiarios activos que ya tiene la cuenta
 DECLARE @EsBeneficiarioActivo BIT; -- 1 si la persona ya es beneficiaria activa de la cuenta
 DECLARE @IdPersonaBeneficiario INT; -- id de la persona beneficiaria en la tabla persona
 DECLARE @jsonNuevo VARCHAR(MAX); -- datos del nuevo beneficiario en json para la bitacora

 --Traducir el numero de cuenta el ID de la cuenta para obtener el valor de la variable IdCuenta
 SELECT @IdCuenta = C.Id
 FROM dbo.Cuenta AS C
 WHERE C.NumeroCuenta = @in_NumeroCuenta

 -- mapea el username al id y a los privilegios del usuario
 SELECT @IdUsuario = U.Id, @EsAdmin = U.EsAdministrador
 FROM dbo.Usuario AS U
 WHERE U.Username = @in_Username;

 -- cuenta los beneficiarios activos de la cuenta
 SELECT @CantidadActivos = COUNT(*)
 FROM dbo.Beneficiario AS B
 WHERE B.IdCuenta = @IdCuenta
 AND B.Activo = 1;

 -- revisa si la persona ya es beneficiaria activa de esta cuenta
 SET @EsBeneficiarioActivo = CASE WHEN EXISTS (
  SELECT 1
  FROM dbo.Beneficiario AS B
  INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
  WHERE B.IdCuenta = @IdCuenta
  AND B.Activo = 1
  AND P.ValorDocumentoIdentidad = @in_ValorDoc
 ) THEN 1 ELSE 0 END;

 -- determina el codigo con la primera validacion que falle
 SET @out_Codigo = CASE
  WHEN @IdUsuario IS NULL THEN 5
  WHEN @EsAdmin = 0 AND NOT EXISTS (SELECT 1 FROM dbo.Usuarios_Ver AS UV WHERE UV.IdUsuario = @IdUsuario AND UV.IdCuenta = @IdCuenta) THEN 3
  WHEN @in_Porcentaje IS NULL OR @in_Porcentaje <= 0 OR @in_Porcentaje > 100 THEN 6
  WHEN @CantidadActivos >= 3 THEN 1
  WHEN @EsBeneficiarioActivo = 1 THEN 4
  ELSE 0
 END;

 -- mensaje que corresponde al codigo
 SET @out_Mensaje = CASE @out_Codigo
  WHEN 0 THEN 'Beneficiario agregado exitosamente'
  WHEN 1 THEN 'La cuenta ya alcanzo el limite de beneficiarios'
  WHEN 3 THEN 'La cuenta indicada no pertenece al usuario'
  WHEN 4 THEN 'Esta persona ya es beneficiaria activa de la cuenta'
  WHEN 5 THEN 'El usuario no existe'
  WHEN 6 THEN 'El porcentaje debe estar entre 1 y 100'
 END;

 -- si fallo alguna validacion se responde sin abrir la transaccion
 IF @out_Codigo <> 0
 BEGIN
  SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
  RETURN;
 END;

 BEGIN TRY
  BEGIN TRANSACTION tAgregarBeneficiario;

  -- crea la persona solo si todavia no existe
  INSERT INTO dbo.Persona (IdTipoDoc, Nombre, ValorDocumentoIdentidad, FechaNacimiento, Email, telefono1, telefono2)
  SELECT @in_TipoDoc, @in_NombrePersona, @in_ValorDoc, @in_FechaNac, @in_Email, @in_Tel1, @in_Tel2
  WHERE NOT EXISTS (
   SELECT 1 FROM dbo.Persona AS P WHERE P.ValorDocumentoIdentidad = @in_ValorDoc
  );

  -- mapea el documento al id de la persona
  SELECT @IdPersonaBeneficiario = P.Id
  FROM dbo.Persona AS P
  WHERE P.ValorDocumentoIdentidad = @in_ValorDoc;

  -- inserta el beneficiario ligado a la cuenta y a la persona por id
  INSERT INTO dbo.Beneficiario (IdCuenta, IdPersonaBeneficiario, IdParentesco, Porcentaje, Activo)
  VALUES (@IdCuenta, @IdPersonaBeneficiario, @in_IdParentesco, @in_Porcentaje, 1);

  -- arma el json con los datos del beneficiario
  SET @jsonNuevo = (
   SELECT P.Nombre, P.ValorDocumentoIdentidad AS Documento, @in_Porcentaje AS Porcentaje
   FROM dbo.Persona AS P
   WHERE P.Id = @IdPersonaBeneficiario
   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );

  -- registra en bitacora, tipo de operacion 3 agregar beneficiario
  INSERT INTO dbo.Bitacora (IdUsuario, IdTipoOperacion, JsonDespues, IP, FechaHora)
  VALUES (@IdUsuario, 3, @jsonNuevo, @in_IP, GETDATE());

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
 SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
END;
