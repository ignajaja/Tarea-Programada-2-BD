USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerParentescos
 @out_ResultCode INT = 0 OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion
 EXEC dbo.sp_ObtenerParentescos
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  -- lista todos los parentescos ordenados por id
  SELECT P.Id
   , P.Nombre
  FROM dbo.Parentesco AS P
  ORDER BY P.Id;
 END TRY
 BEGIN CATCH
  SET @out_ResultCode = 50000;
 END CATCH;
END;
GO
