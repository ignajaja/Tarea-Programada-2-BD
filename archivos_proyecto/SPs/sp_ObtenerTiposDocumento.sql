USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerTiposDocumento
 @out_ResultCode INT = 0 OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ObtenerTiposDocumento
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  -- lista todos los tipos de documento ordenados por id
  SELECT TD.Id
   , TD.Nombre
  FROM dbo.Tipo_Doc AS TD
  ORDER BY TD.Id;
 END TRY
 BEGIN CATCH
  SET @out_ResultCode = 50000;
 END CATCH;
END;
GO
