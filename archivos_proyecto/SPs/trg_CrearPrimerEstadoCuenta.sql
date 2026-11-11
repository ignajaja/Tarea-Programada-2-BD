USE [TareaProgramada2]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER TRIGGER dbo.trg_CrearPrimerEstadoCuenta
ON dbo.Cuenta
AFTER INSERT
AS
/*
este trigger se activa al insertar en cuenta
se puede probar insertando una cuenta nueva por ejemplo:
 INSERT INTO dbo.Cuenta (IdTipoCuenta, NumeroCuenta, FechaCreacion, Saldo, IdPersona)
 VALUES (1, '99999999', '2026-03-01', 0, 1)
 SELECT EC.Id, EC.IdCuenta, EC.fechaInicio, EC.fechafin, EC.saldoinicial FROM dbo.Estado_Cuenta AS EC WHERE EC.IdCuenta = SCOPE_IDENTITY()
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  -- abre el primer estado de cuenta de cada cuenta insertada
  -- inicia el mismo dia de creacion
  -- termina un mes despues de la creacion, ese dia se hace el primer cierre
  INSERT INTO dbo.Estado_Cuenta (
   IdCuenta
   , fechaInicio
   , fechafin
   , saldoinicial
   , saldo_final
   , saldoMinimo
   , interesesAcumulados
   , cantRetiros
   , cantDepositos
   , cantSinpeEntrantes
   , cantSinpeSalientes
   , cantOperacionesATM
   , cantOperacionesHumano
  )
  SELECT
   i.Id
   , i.FechaCreacion 					--dia de creacion de la cuenta inicia el primer estado
   , DATEADD(month, 1, i.FechaCreacion) --cierra un mes despues de la fecha de creacion
   , i.Saldo
   , i.Saldo
   , i.Saldo
   , 0.00
   , 0
   , 0
   , 0
   , 0
   , 0
   , 0
  FROM inserted AS i;
 END TRY
 BEGIN CATCH
  -- si falla el estado de cuenta se deshace la insercion de la cuenta y se informa el error
  IF @@TRANCOUNT > 0
  BEGIN
   ROLLBACK TRANSACTION;
  END;

  RAISERROR('Error al abrir el primer estado de cuenta', 16, 1);
 END CATCH;
END;
GO
