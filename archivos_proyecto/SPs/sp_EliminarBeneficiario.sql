USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_EliminarBeneficiario] Fecha de script: 11/19/2026 11:00:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_EliminarBeneficiario]
 @in_Username VARCHAR(64) -- usuario que realiza la eliminacion
 , @in_BeneficiarioId INT -- id del beneficiario a eliminar
 , @in_IP VARCHAR(64) = '0.0.0.0' -- ip del cliente, por defecto 0.0.0.0 si views.py no la envia
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_EliminarBeneficiario
  @in_Username = 'amora'
  , @in_BeneficiarioId = 1
  , @in_IP = '127.0.0.1'
devuelve una fila con Codigo y Mensaje, codigo 0 es exito
la eliminacion es logica, el beneficiario queda inactivo con su fecha de desactivacion
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  DECLARE @Codigo INT = 0; -- 0 exito, 1 beneficiario no existe o inactivo, 2 error de bd, 3 usuario no existe, 4 cuenta no pertenece al usuario
  DECLARE @Mensaje VARCHAR(256) = 'Beneficiario eliminado correctamente'; -- mensaje del resultado
  DECLARE @IdUsuario INT; -- id del usuario que elimina
  DECLARE @flagEsAdmin BIT = 0; -- 1 si el usuario es administrador
  DECLARE @flagTieneAcceso BIT = 0; -- 1 si el usuario puede modificar la cuenta del beneficiario
  DECLARE @IdCuenta INT; -- cuenta a la que pertenece el beneficiario
  DECLARE @NombreAnterior VARCHAR(128); -- nombre de la persona beneficiaria
  DECLARE @NombreParentesco VARCHAR(64); -- nombre del parentesco del beneficiario
  DECLARE @PorcentajeAnterior INT; -- porcentaje del beneficiario antes de eliminarlo
  DECLARE @jsonAntes VARCHAR(MAX); -- datos del beneficiario antes de eliminarlo

  -- mapea el username al id y a los privilegios del usuario
  SELECT @IdUsuario = U.Id
   , @flagEsAdmin = U.EsAdministrador
  FROM dbo.Usuario AS U
  WHERE U.Username = @in_Username;

  -- mapea el beneficiario a su cuenta y trae sus datos actuales, solo si esta activo
  SELECT @IdCuenta = B.IdCuenta
   , @NombreAnterior = P.Nombre
   , @NombreParentesco = PA.Nombre
   , @PorcentajeAnterior = B.Porcentaje
  FROM dbo.Beneficiario AS B
  INNER JOIN dbo.Persona AS P ON P.Id = B.IdPersonaBeneficiario
  INNER JOIN dbo.Parentesco AS PA ON PA.Id = B.IdParentesco
  WHERE B.Id = @in_BeneficiarioId
  AND B.Activo = 1;

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

  -- determina el codigo y el mensaje con la primera validacion que falle
  IF (@IdUsuario IS NULL)
  BEGIN
   SET @Codigo = 3;
   SET @Mensaje = 'El usuario no existe';
  END
  ELSE IF (@IdCuenta IS NULL)
  BEGIN
   SET @Codigo = 1;
   SET @Mensaje = 'El beneficiario no existe o ya esta inactivo';
  END
  ELSE IF (@flagTieneAcceso = 0)
  BEGIN
   SET @Codigo = 4;
   SET @Mensaje = 'El beneficiario no pertenece a una cuenta del usuario';
  END;

  -- si fallo alguna validacion se responde sin abrir la transaccion
  IF @Codigo > 0
  BEGIN
   SELECT @Codigo AS Codigo
    , @Mensaje AS Mensaje;
   RETURN;
  END;

  -- guarda los datos del beneficiario antes de eliminarlo
  SET @jsonAntes = '{"Nombre":"' + @NombreAnterior
   + '","Parentesco":"' + @NombreParentesco
   + '","Porcentaje":' + CONVERT(VARCHAR(8), @PorcentajeAnterior) + '}';

  BEGIN TRANSACTION tEliminarBeneficiario;

  -- eliminacion logica
  UPDATE dbo.Beneficiario
  SET Activo = 0
      , FechaDesactivacion = GETDATE()
  WHERE Id = @in_BeneficiarioId;

  -- registra en bitacora, tipo de operacion 5 eliminar beneficiario
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
   , 5
   , @jsonAntes
   , NULL
   , @in_IP
   , GETDATE()
  );

  COMMIT TRANSACTION tEliminarBeneficiario;
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
