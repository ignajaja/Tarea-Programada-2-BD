CREATE OR ALTER TRIGGER dbo.trg_CrearPrimerEstadoCuenta
ON dbo.Cuenta --el trigger es para la tabla Cuenta
AFTER INSERT
AS
/*
trigger de creacion del primer estado de cuenta al crear una Cuenta
se dispara solo al insertar filas en cuenta, se puede probar al insertar una nueva cuenta por ejemplo
 INSERT INTO dbo.Cuenta (IdTipoCuenta, NumeroCuenta, FechaCreacion, Saldo, IdPersona)
 VALUES (1, '99999999', '2026-03-01', 0, 1)
 SELECT * FROM dbo.Estado_Cuenta WHERE IdCuenta = SCOPE_IDENTITY()
*/
BEGIN
	-- desactivar el conteo de filas afectadas
	SET NOCOUNT ON;
 
	-- verificar que se haya ingresado algun registro en la tabla inserted si no no se crea
    IF NOT EXISTS (
        SELECT 1 
        FROM inserted
    )
    BEGIN
        RETURN
    END

	-- registro del primer periodo de estado de cuenta para cada cuenta nueva creada
	INSERT INTO dbo.Estado_Cuenta (
		IdCuenta,
		fechaInicio,
		fechafin,
		saldoinicial,
		saldo_final,
		saldoMinimo,
		interesesAcumulados,
		cantRetiros,
		cantDepositos,
		cantSinpeEntrantes,
		cantSinpeSalientes,
		cantOperacionesATM,
		cantOperacionesHumano
	)
	
	-- extraccion y mapeo de los valores iniciales desde la tabla inserted 
	SELECT
		i.id, -- id de la cuenta insertada, la da inserted para insertarla en el estado de cuenta en IdCuenta
        dateadd(day, 1, i.[FechaCreacion]), -- fecha de inicio del periodo (dia siguiente a la creacion de la cuenta)
        dateadd(month, 1, i.[FechaCreacion]), -- fecha de cierre sumando un mes a la fecha de creacion
        i.saldo, -- saldo inicial del periodo
        i.saldo, -- saldo final del periodo con el mismo monto de apertura
        i.saldo, -- saldo minimo arrancando con el saldo inicial actual
        0.00, -- inicializacion de intereses acumulados en cero
        0, -- inicializacion contador de retiros en 0
        0, -- inicializacion contador depositos en 0
        0, -- incializacion contador transferencias entrantes en 0
        0, -- incializacion contador transferencias salientes en 0
        0, -- incializacion contador operacions en atm en 0
        0  -- incializacion contador operaciones humanas en 0
 FROM inserted AS i;
 END;
