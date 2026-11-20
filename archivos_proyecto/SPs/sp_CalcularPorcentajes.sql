USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_CalcularPorcentajes] Fecha de script: 11/19/2026 10:54:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_CalcularPorcentajes]
 @in_IdCuenta INT = NULL -- id de la cuenta cuyos porcentajes se suman
 , @in_BeneficiarioId INT = NULL -- alternativa, id de un beneficiario para ubicar su cuenta
 , @out_ResultCode INT = 0 OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion por cuenta
 EXEC dbo.sp_CalcularPorcentajes @in_IdCuenta = 1
ejemplo de ejecucion por beneficiario
 EXEC dbo.sp_CalcularPorcentajes @in_BeneficiarioId = 3
devuelve IdCuenta y SumaTotal, la aplicacion muestra la alerta cuando SumaTotal es menor que 100
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  SET @out_ResultCode = 0;

  DECLARE @IdCuenta INT = @in_IdCuenta; -- cuenta que se va a sumar
  DECLARE @SumaTotal INT; -- suma de los porcentajes de los beneficiarios activos

  -- si no se recibio la cuenta se busca a partir del beneficiario
  IF (@IdCuenta IS NULL)
  BEGIN
   SELECT @IdCuenta = B.IdCuenta
   FROM dbo.Beneficiario AS B
   WHERE B.Id = @in_BeneficiarioId;
  END;

  -- suma solo los porcentajes de los beneficiarios activos de esa cuenta
  SELECT @SumaTotal = SUM(B.Porcentaje)
  FROM dbo.Beneficiario AS B
  WHERE B.IdCuenta = @IdCuenta
  AND B.Activo = 1;

  -- si la cuenta no tiene beneficiarios activos la suma queda en null
  IF (@SumaTotal IS NULL)
  BEGIN
   SET @SumaTotal = 0;
  END;

  SELECT @IdCuenta AS IdCuenta
   , @SumaTotal AS SumaTotal;
 END TRY
 BEGIN CATCH
  SET @out_ResultCode = 50000;
 END CATCH;
END;
