USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_ActualizarBeneficiario] Fecha de script: 11/19/2026 10:50:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_ActualizarBeneficiario]
 @in_Username VARCHAR(64) -- usuario que realiza la actualizacion
 , @in_BeneficiarioId INT -- id del beneficiario a modificar
 , @in_NombrePersona VARCHAR(128) -- nuevo nombre de la persona
 , @in_IdParentesco INT -- nuevo id de parentesco
 , @in_Porcentaje INT -- nuevo porcentaje
 , @in_IP VARCHAR(64) = '0.0.0.0' -- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
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
  DECLARE @Codigo INT = 0; -- 0 exito, 1 beneficiario no existe o inactivo, 2 error de bd, 3 usuario no existe, 4 cuenta no pertenece al usuario, 5 porcentaje invalido, 6 parentesco no existe
  DECLARE @Mensaje VARCHAR(256) = 'Beneficiario actualizado correctamente'; -- mensaje del resultado
  DECLARE @IdUsuario INT; -- id del usuario que actualiza
  DECLARE @flagEsAdmin BIT = 0; -- 1 si el usuario es administrador
  DECLARE @flagTieneAcceso BIT = 0; -- 1 si el usuario puede modificar la cuenta del beneficiario
  DECLARE @IdCuenta INT; -- cuenta a la que pertenece el beneficiario
  DECLARE @IdPersonaBeneficiario INT; -- persona ligada al beneficiario
  DECLARE @NombreAnterior VARCHAR(128); -- nombre de la persona antes del cambio
  DECLARE @ParentescoAnterior INT; -- parentesco antes del cambio
  DECLARE @NombreParentescoAnterior VARCHAR(64); -- nombre del parentesco antes del cambio
  DECLARE @NombreParentescoNuevo VARCHAR(64); -- nombre del parentesco nuevo, queda en null si no existe
  DECLARE @PorcentajeAnterior INT; -- porcentaje antes del cambio
  DECLARE @IdTipoOperacion INT = 4; -- tipo de operacion para la bitacora, 6 si solo cambio el porcentaje y 4 en los demas casos
  DECLARE @jsonAntes VARCHAR(MAX); -- datos del beneficiario antes del cambio
  DECLARE @jsonDespues VARCHAR(MAX); -- datos del beneficiario despues del cambio

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
   , @NombreParentescoAnterior = PA.Nombre
   , @PorcentajeAnterior = B.Porcentaje
  FROM dbo.Beneficiario AS B
  INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
  INNER JOIN dbo.Parentesco AS PA ON PA.Id = B.IdParentesco
  WHERE B.Id = @in_BeneficiarioId
  AND B.Activo = 1;

  -- mapea el parentesco nuevo a su nombre
  SELECT @NombreParentescoNuevo = PA.Nombre
  FROM dbo.Parentesco AS PA
  WHERE PA.Id = @in_IdParentesco;

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

  -- si solo cambio el porcentaje se registra como actualizar porcentaje (6), si no como actualizar beneficiario (4)
  IF (@NombreAnterior = @in_NombrePersona
   AND @ParentescoAnterior = @in_IdParentesco
   AND @PorcentajeAnterior <> @in_Porcentaje)
  BEGIN
   SET @IdTipoOperacion = 6;
  END;

  -- determina el codigo y el mensaje con la primera validacion que falle
  IF (@IdUsuario IS NULL)
  BEGIN
   SET @Codigo = 3;
   SET @Mensaje = 'El usuario no existe';
  END
  ELSE IF (@IdCuenta IS NULL)
  BEGIN
   SET @Codigo = 1;
   SET @Mensaje = 'El beneficiario no existe o esta inactivo';
  END
  ELSE IF (@flagTieneAcceso = 0)
  BEGIN
   SET @Codigo = 4;
   SET @Mensaje = 'El beneficiario no pertenece a una cuenta del usuario';
  END
  ELSE IF (@in_Porcentaje IS NULL OR @in_Porcentaje <= 0 OR @in_Porcentaje > 100)
  BEGIN
   SET @Codigo = 5;
   SET @Mensaje = 'El porcentaje debe estar entre 1 y 100';
  END
  ELSE IF (@NombreParentescoNuevo IS NULL)
  BEGIN
   SET @Codigo = 6;
   SET @Mensaje = 'El parentesco indicado no existe';
  END;

  -- si fallo alguna validacion se responde sin abrir la transaccion
  IF @Codigo > 0
  BEGIN
   SELECT @Codigo AS Codigo
    , @Mensaje AS Mensaje;
   RETURN;
  END;

  -- arma el json del estado anterior y del posterior
  SET @jsonAntes = '{"Nombre":"' + @NombreAnterior
   + '","Parentesco":"' + @NombreParentescoAnterior
   + '","Porcentaje":' + CONVERT(VARCHAR(8), @PorcentajeAnterior) + '}';

  SET @jsonDespues = '{"Nombre":"' + @in_NombrePersona
   + '","Parentesco":"' + @NombreParentescoNuevo
   + '","Porcentaje":' + CONVERT(VARCHAR(8), @in_Porcentaje) + '}';

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
  SET @Codigo = 2;
  SET @Mensaje = ERROR_MESSAGE();
 END CATCH;

 -- devuelve el resultado final
 SELECT @Codigo AS Codigo
  , @Mensaje AS Mensaje;
END;
