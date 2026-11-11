USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_LimpiarBaseDatos
 @out_ResultCode INT OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 DECLARE @resultado INT
 EXEC dbo.sp_LimpiarBaseDatos @out_ResultCode = @resultado OUTPUT
 SELECT @resultado AS ResultCode
borra los datos de todas las tablas para poder repetir la carga de catalogos y la simulacion desde cero
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  -- inicia en exito
  SET @out_ResultCode = 0;

  -- todos los borrados se hacen en una transaccion, se borra primero lo que depende de otras tablas
  BEGIN TRANSACTION tLimpiarBaseDatos;

  DELETE FROM dbo.Bitacora_Simulacion;
  DELETE FROM dbo.Simulacion_Control;
  DELETE FROM dbo.Comprobante_Movimiento;
  DELETE FROM dbo.Bitacora;
  DELETE FROM dbo.Usuarios_Ver;
  DELETE FROM dbo.Movimiento;
  DELETE FROM dbo.Estado_Cuenta;
  DELETE FROM dbo.Beneficiario;
  DELETE FROM dbo.Usuario;
  DELETE FROM dbo.Cuenta;
  DELETE FROM dbo.Persona;
  DELETE FROM dbo.TipoOperacion;
  DELETE FROM dbo.Tipos_Movimiento;
  DELETE FROM dbo.Tipo_Cuenta_Ahorros;
  DELETE FROM dbo.Parentesco;
  DELETE FROM dbo.Tipo_Moneda;
  DELETE FROM dbo.Tipo_Doc;

  COMMIT TRANSACTION tLimpiarBaseDatos;
 END TRY
 BEGIN CATCH
  -- ante cualquier error se deshacen todos los borrados
  IF @@TRANCOUNT > 0
  BEGIN
   ROLLBACK TRANSACTION;
  END;

  SET @out_ResultCode = 50000;
 END CATCH;
END;
GO
