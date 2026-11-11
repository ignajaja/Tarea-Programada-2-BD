USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_ActualizarBeneficiario
 @in_Username VARCHAR(64) 			-- usuario que realiza la actualizacion
 , @in_BeneficiarioId INT 			-- id del beneficiario a modificar
 , @in_NombrePersona VARCHAR(128) 	-- nuevo nombre de la persona
 , @in_IdParentesco INT 			-- nuevo id de parentesco
 , @in_Porcentaje INT 				-- nuevo porcentaje
 , @in_IP VARCHAR(64) = '0.0.0.0' 	-- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ActualizarBeneficiario
  @in_Username = 'amora'
  , @in_BeneficiarioId = 1
  , @in_NombrePersona = 'Rosa Jimenez Arias'
  , @in_IdParentesco = 2
  , @in_Porcentaje = 50
  , @in_IP = '127.0.0.1'
devuelve una fila con Codigo y Mensaje, codigo 0 es exito
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  DECLARE @out_Codigo INT; 				-- 0 exito, 1 beneficiario no existe o inactivo, 2 error de bd, 3 usuario no existe, 4 cuenta no pertenece al usuario, 5 porcentaje invalido, 6 parentesco no existe
  DECLARE @out_Mensaje VARCHAR(256); 	-- mensaje del resultado
  DECLARE @IdUsuario INT; 				-- id del usuario que actualiza
  DECLARE @flagEsAdmin BIT = 0; 		-- 1 si el usuario es administrador
  DECLARE @IdCuenta INT; 				-- cuenta a la que pertenece el beneficiario
  DECLARE @IdPersonaBeneficiario INT; 	-- persona ligada al beneficiario
  DECLARE @NombreAnterior VARCHAR(128); -- nombre de la persona antes del cambio
  DECLARE @ParentescoAnterior INT; 		-- parentesco antes del cambio
  DECLARE @PorcentajeAnterior INT; 		-- porcentaje antes del cambio
  DECLARE @IdTipoOperacion INT; 		-- tipo de operacion para la bitacora, 6 si solo cambio el porcentaje y 4 en los demas casos
  DECLARE @jsonAntes VARCHAR(MAX); 		-- datos del beneficiario antes del cambio
  DECLARE @jsonDespues VARCHAR(MAX); 	-- datos del beneficiario despues del cambio

  -- mapea el username al id y a los privilegios del usuario
  SELECT @IdUsuario = U.Id
   , @flagEsAdmin = U.EsAdministrador
  FROM dbo.Usuario AS U
  WHERE U.Username = @in_Username;

  -- mapea el beneficiario a su cuenta y a su persona y trae sus valores actuales, solo si esta activo
  SELECT
   @IdCuenta = B.IdCuenta
   , @IdPersonaBeneficiario = B.IdPersonaBeneficiario
   , @NombreAnterior = P.Nombre
   , @ParentescoAnterior = B.IdParentesco
   , @PorcentajeAnterior = B.Porcentaje
  FROM dbo.Beneficiario AS B
  INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
  WHERE B.Id = @in_BeneficiarioId
  AND B.Activo = 1;

  -- si solo cambio el porcentaje se registra como actualizar porcentaje (6), si no como actualizar beneficiario (4)
  SET @IdTipoOperacion = CASE
   WHEN (@NombreAnterior = @in_NombrePersona
    AND @ParentescoAnterior = @in_IdParentesco
    AND @PorcentajeAnterior <> @in_Porcentaje) THEN 6
   ELSE 4
  END;

  -- determina el codigo con la primera validacion que falle
  SET @out_Codigo = CASE
   WHEN @IdUsuario IS NULL THEN 3
   WHEN @IdCuenta IS NULL THEN 1
   WHEN (@flagEsAdmin = 0 AND NOT EXISTS (SELECT 1 FROM dbo.Usuarios_Ver AS UV WHERE UV.IdUsuario = @IdUsuario AND UV.IdCuenta = @IdCuenta)) THEN 4
   WHEN (@in_Porcentaje IS NULL OR @in_Porcentaje <= 0 OR @in_Porcentaje > 100) THEN 5
   WHEN NOT EXISTS (SELECT 1 FROM dbo.Parentesco AS PA WHERE PA.Id = @in_IdParentesco) THEN 6
   ELSE 0
  END;

  -- mensaje que corresponde al codigo
  SET @out_Mensaje = CASE @out_Codigo
   WHEN 0 THEN 'Beneficiario actualizado correctamente'
   WHEN 1 THEN 'El beneficiario no existe o esta inactivo'
   WHEN 3 THEN 'El usuario no existe'
   WHEN 4 THEN 'El beneficiario no pertenece a una cuenta del usuario'
   WHEN 5 THEN 'El porcentaje debe estar entre 1 y 100'
   WHEN 6 THEN 'El parentesco indicado no existe'
  END;

  -- si fallo alguna validacion se responde sin abrir la transaccion
  IF @out_Codigo > 0
  BEGIN
   SELECT @out_Codigo AS Codigo
    , @out_Mensaje AS Mensaje;
   RETURN;
  END;

  -- guarda el estado anterior en json
  SET @jsonAntes = (
   SELECT P.Nombre
    , PA.Nombre AS Parentesco
    , B.Porcentaje
   FROM dbo.Beneficiario AS B
   INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
   INNER JOIN dbo.Parentesco AS PA ON PA.Id = B.IdParentesco
   WHERE B.Id = @in_BeneficiarioId
   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );

  -- arma el json del estado posterior con los valores nuevos
  SET @jsonDespues = (
   SELECT
    @in_NombrePersona AS Nombre
    , PA.Nombre AS Parentesco
    , @in_Porcentaje AS Porcentaje
   FROM dbo.Parentesco AS PA
   WHERE PA.Id = @in_IdParentesco
   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );

  BEGIN TRANSACTION tActualizarBeneficiario;

  -- actualiza el nombre en persona
  UPDATE dbo.Persona
  SET Nombre = @in_NombrePersona
  WHERE Id = @IdPersonaBeneficiario;

  -- actualiza parentesco y porcentaje en beneficiario
  UPDATE dbo.Beneficiario
  SET IdParentesco = @in_IdParentesco
      , Porcentaje = @in_Porcentaje
  WHERE Id = @in_BeneficiarioId;

  -- registra en bitacora con el tipo de operacion calculado
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
   , @IdTipoOperacion
   , @jsonAntes
   , @jsonDespues
   , @in_IP
   , GETDATE()
  );

  COMMIT TRANSACTION tActualizarBeneficiario;
 END TRY
 BEGIN CATCH
  -- ante un error se deshacen los cambios
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
GO
