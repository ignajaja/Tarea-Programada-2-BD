USE [TareaProgramada2]
GO
/****** Objeto: Trigger [dbo].[trg_CrearPrimerEstadoCuenta] Fecha de script: 11/19/2026 10:49:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   TRIGGER [dbo].[trg_CrearPrimerEstadoCuenta]
ON [dbo].[Cuenta]
AFTER INSERT
AS
/*
este trigger se activa al insertar en cuenta
no lleva try catch ni transaccion porque el sp que inserta la cuenta ya los tiene
se puede probar insertando una cuenta nueva, por ejemplo
 INSERT INTO dbo.Cuenta (IdTipoCuenta, IdPersona, NumeroCuenta, FechaCreacion, Saldo)
 VALUES (1, 1, '99999999', '2026-03-01', 0)
 SELECT EC.Id, EC.IdCuenta, EC.fechaInicio, EC.fechafin, EC.saldoinicial FROM dbo.Estado_Cuenta AS EC WHERE EC.IdCuenta = SCOPE_IDENTITY()
*/
BEGIN
 SET NOCOUNT ON;

 -- abre el primer estado de cuenta de cada cuenta insertada, el trigger supone una insercion masiva
 -- inicia el mismo dia de la creacion y termina un mes despues, ese dia se hace el primer cierre
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
  I.Id
  , I.FechaCreacion
  , DATEADD(month, 1, I.FechaCreacion)
  , I.Saldo
  , I.Saldo
  , I.Saldo
  , 0.00
  , 0
  , 0
  , 0
  , 0
  , 0
  , 0
 FROM inserted AS I;
END;
