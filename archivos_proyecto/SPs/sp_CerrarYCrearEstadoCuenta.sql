CREATE OR ALTER PROCEDURE dbo.sp_CerrarYCrearEstadoCuenta
    @in_IdCuenta INT, -- id de la cuenta a la que se le cierra el estado de cuenta
    @in_FechaProceso DATE, -- fecha de la simulacion, se cierra el estado que termina ese dia
    @out_ResultCode INT OUTPUT -- 0 exito (o nada que cerrar), 50000 error de bd
AS
/*
ejemplo de ejecucion:
    DECLARE @resultado INT
    EXEC dbo.sp_CerrarYCrearEstadoCuenta
        @in_IdCuenta = 1,
        @in_FechaProceso = '2026-04-01',
        @out_ResultCode = @resultado OUTPUT
    SELECT @resultado AS ResultCode
*/
BEGIN
    -- desactivar el conteo de filas afectadas
    SET NOCOUNT ON

    -- inicia en exito
    SET @out_ResultCode = 0

    -- nombres de los tipos de movimiento que genera el cierre
    DECLARE @NomIntereses VARCHAR(64) = 'Intereses Mensuales' -- credito por intereses
    DECLARE @NomComisionAtm VARCHAR(64) = 'Comision Exceso ATM' -- debito por exceso de operaciones atm
    DECLARE @NomComisionHumano VARCHAR(64) = 'Comision Exceso Ventana' -- debito por exceso de operaciones con cajero humano
    DECLARE @NomMulta VARCHAR(64) = 'Multa Saldo Minimo' -- debito por saldo minimo inferior al permitido
    DECLARE @NomCargo VARCHAR(64) = 'Cargo Servicio Mensual' -- debito por cargo de servicio

    -- datos del estado de cuenta que se cierra
    DECLARE @IdEstadoCuenta INT -- id del estado de cuenta que termina en la fecha de proceso
    DECLARE @FechaCreacion DATE -- fecha de creacion de la cuenta, define el dia de cierre de cada mes
    DECLARE @FechaFinEstado DATE -- fecha de fin del estado que se cierra
    DECLARE @SaldoFinalActual DECIMAL(18,2) -- saldo con el que llega el estado antes del cierre
    DECLARE @SaldoMinimoPeriodo DECIMAL(18,2) -- saldo minimo que tuvo la cuenta en el periodo
    DECLARE @CantOpAtm INT -- operaciones atm del periodo
    DECLARE @CantOpHumano INT -- operaciones con cajero humano del periodo

    -- datos del tipo de cuenta
    DECLARE @TasaInteresAnual DECIMAL(5,2) -- tasa de interes anual en porcentaje
    DECLARE @SaldoMinimoPermitido DECIMAL(18,2) -- saldo minimo que exige el tipo de cuenta
    DECLARE @MultaSaldoMin DECIMAL(18,2) -- multa si el saldo minimo del periodo fue inferior al permitido
    DECLARE @CargoMensual DECIMAL(18,2) -- cargo por servicio mensual
    DECLARE @NumRetirosAutomatico INT -- operaciones atm permitidas sin comision
    DECLARE @NumRetirosHumano INT -- operaciones con cajero humano permitidas sin comision
    DECLARE @ComisionAutomatico DECIMAL(18,2) -- comision por cada operacion atm de exceso
    DECLARE @ComisionHumano DECIMAL(18,2) -- comision por cada operacion con cajero humano de exceso

    -- montos calculados del cierre
    DECLARE @MontoIntereses DECIMAL(18,2) -- intereses del mes sobre el saldo minimo
    DECLARE @MontoComisionAtm DECIMAL(18,2) -- comision total por exceso de operaciones atm
    DECLARE @MontoComisionHumano DECIMAL(18,2) -- comision total por exceso de operaciones con cajero humano
    DECLARE @MontoMulta DECIMAL(18,2) -- multa por saldo minimo
    DECLARE @MontoCargo DECIMAL(18,2) -- cargo por servicio

    -- saldo despues de aplicar cada movimiento del cierre, se usa como nuevo saldo de cada uno
    DECLARE @SaldoTrasIntereses DECIMAL(18,2)
    DECLARE @SaldoTrasComisionAtm DECIMAL(18,2)
    DECLARE @SaldoTrasComisionHumano DECIMAL(18,2)
    DECLARE @SaldoTrasMulta DECIMAL(18,2)
    DECLARE @NuevoSaldoFinal DECIMAL(18,2) -- saldo despues de todos los movimientos del cierre

    -- datos del estado de cuenta nuevo
    DECLARE @MesesTranscurridos INT -- meses entre la creacion de la cuenta y el cierre
    DECLARE @FechaInicioNuevo DATE -- inicio del nuevo estado, dia siguiente al cierre
    DECLARE @FechaFinNuevo DATE -- fin del nuevo estado, mismo dia del mes que la creacion de la cuenta

    -- busca el estado que termina hoy y que todavia no tiene un estado siguiente (evita cerrarlo dos veces)
    SELECT
        @IdEstadoCuenta = EC.Id,
        @FechaCreacion = C.FechaCreacion,
        @FechaFinEstado = EC.fechafin,
        @SaldoFinalActual = EC.saldo_final,
        @SaldoMinimoPeriodo = ISNULL(EC.saldoMinimo, EC.saldo_final),
        @CantOpAtm = EC.cantOperacionesATM,
        @CantOpHumano = EC.cantOperacionesHumano,
        @TasaInteresAnual = ISNULL(TCA.TasaInteresAnual, 0),
        @SaldoMinimoPermitido = TCA.SaldoMinimo,
        @MultaSaldoMin = TCA.MultaSaldoMin,
        @CargoMensual = ISNULL(TCA.CargoMensual, 0),
        @NumRetirosAutomatico = TCA.NumRetirosAutomatico,
        @NumRetirosHumano = TCA.NumRetirosHumano,
        @ComisionAutomatico = TCA.comisionAutomatico,
        @ComisionHumano = TCA.comisionHumano
    FROM dbo.Estado_Cuenta AS EC
    INNER JOIN dbo.Cuenta AS C 
        ON C.Id = EC.IdCuenta
    INNER JOIN dbo.Tipo_Cuenta_Ahorros AS TCA 
        ON TCA.Id = C.IdTipoCuenta
    WHERE EC.IdCuenta = @in_IdCuenta
      AND EC.fechafin = @in_FechaProceso
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.Estado_Cuenta AS Siguiente
          WHERE Siguiente.IdCuenta = EC.IdCuenta
            AND Siguiente.fechaInicio > EC.fechafin
      )

    -- si no hay estado por cerrar no se hace nada
    IF @IdEstadoCuenta IS NULL
    BEGIN
        RETURN
    END

    -- intereses del mes, tasa anual dividida entre 12 aplicada al saldo minimo del periodo
    SET @MontoIntereses = ROUND(@SaldoMinimoPeriodo * (@TasaInteresAnual / 100.0 / 12.0), 2)

    -- comision por las operaciones atm que exceden el maximo permitido
    SET @MontoComisionAtm = CASE
        WHEN @CantOpAtm > @NumRetirosAutomatico THEN (@CantOpAtm - @NumRetirosAutomatico) * ISNULL(@ComisionAutomatico, 0)
        ELSE 0
    END

    -- comision por las operaciones con cajero humano que exceden el maximo permitido
    SET @MontoComisionHumano = CASE
        WHEN @CantOpHumano > @NumRetirosHumano THEN (@CantOpHumano - @NumRetirosHumano) * ISNULL(@ComisionHumano, 0)
        ELSE 0
    END

    -- multa si en algun momento el saldo fue inferior al minimo permitido
    SET @MontoMulta = CASE 
        WHEN @SaldoMinimoPeriodo < @SaldoMinimoPermitido THEN ISNULL(@MultaSaldoMin, 0) 
        ELSE 0 
    END

    -- cargo por servicio mensual
    SET @MontoCargo = @CargoMensual

    -- saldo despues de cada movimiento en el orden en que se insertan
    SET @SaldoTrasIntereses = @SaldoFinalActual + CASE WHEN @MontoIntereses > 0 THEN @MontoIntereses ELSE 0 END
    SET @SaldoTrasComisionAtm = @SaldoTrasIntereses - @MontoComisionAtm
    SET @SaldoTrasComisionHumano = @SaldoTrasComisionAtm - @MontoComisionHumano
    SET @SaldoTrasMulta = @SaldoTrasComisionHumano - @MontoMulta
    SET @NuevoSaldoFinal = @SaldoTrasMulta - @MontoCargo

    -- el nuevo estado termina el mismo dia del mes que la creacion de la cuenta, se calcula desde la creacion para respetar fines de mes
    SET @MesesTranscurridos = DATEDIFF(month, @FechaCreacion, @FechaFinEstado) + 1
    SET @FechaInicioNuevo = DATEADD(day, 1, @FechaFinEstado)
    SET @FechaFinNuevo = DATEADD(month, @MesesTranscurridos, @FechaCreacion)

    BEGIN TRY
        -- el cierre y la apertura de la cuenta se hacen en una sola transaccion
        BEGIN TRANSACTION tCerrarEstadoCuenta

        -- actualiza el saldo de la cuenta
        UPDATE dbo.Cuenta
        SET Saldo = @NuevoSaldoFinal
        WHERE Id = @in_IdCuenta

        -- movimiento de intereses, solo si hay intereses
        INSERT INTO dbo.Movimiento (
            IdCuenta, 
            IdTipoMovimiento, 
            Fecha, 
            Monto, 
            Descripcion, 
            NuevoSaldo
        )
        SELECT 
            @in_IdCuenta, 
            TM.Id, 
            @in_FechaProceso, 
            @MontoIntereses, 
            'Intereses mensuales', 
            @SaldoTrasIntereses
        FROM dbo.Tipos_Movimiento AS TM
        WHERE TM.Nombre = @NomIntereses
          AND @MontoIntereses > 0

        -- movimiento de comision por exceso de atm, solo si hay exceso
        INSERT INTO dbo.Movimiento (
            IdCuenta, 
            IdTipoMovimiento, 
            Fecha, 
            Monto, 
            Descripcion, 
            NuevoSaldo
        )
        SELECT 
            @in_IdCuenta, 
            TM.Id, 
            @in_FechaProceso, 
            @MontoComisionAtm, 
            'Comision por exceso de operaciones en atm', 
            @SaldoTrasComisionAtm
        FROM dbo.Tipos_Movimiento AS TM
        WHERE TM.Nombre = @NomComisionAtm
          AND @MontoComisionAtm > 0

        -- movimiento de comision por exceso de cajero humano, solo si hay exceso
        INSERT INTO dbo.Movimiento (
            IdCuenta, 
            IdTipoMovimiento, 
            Fecha, 
            Monto, 
            Descripcion, 
            NuevoSaldo
        )
        SELECT 
            @in_IdCuenta, 
            TM.Id, 
            @in_FechaProceso, 
            @MontoComisionHumano, 
            'Comision por exceso de operaciones con cajero humano', 
            @SaldoTrasComisionHumano
        FROM dbo.Tipos_Movimiento AS TM
        WHERE TM.Nombre = @NomComisionHumano
          AND @MontoComisionHumano > 0

        -- movimiento de multa por saldo minimo, solo si aplica
        INSERT INTO dbo.Movimiento (
            IdCuenta, 
            IdTipoMovimiento, 
            Fecha, 
            Monto, 
            Descripcion, 
            NuevoSaldo
        )
        SELECT 
            @in_IdCuenta, 
            TM.Id, 
            @in_FechaProceso, 
            @MontoMulta, 
            'Multa por saldo minimo inferior al permitido', 
            @SaldoTrasMulta
        FROM dbo.Tipos_Movimiento AS TM
        WHERE TM.Nombre = @NomMulta
          AND @MontoMulta > 0

        -- movimiento de cargo por servicio mensual, solo si el tipo de cuenta tiene cargo
        INSERT INTO dbo.Movimiento (
            IdCuenta, 
            IdTipoMovimiento, 
            Fecha, 
            Monto, 
            Descripcion, 
            NuevoSaldo
        )
        SELECT 
            @in_IdCuenta, 
            TM.Id, 
            @in_FechaProceso, 
            @MontoCargo, 
            'Cargo por servicio mensual', 
            @NuevoSaldoFinal
        FROM dbo.Tipos_Movimiento AS TM
        WHERE TM.Nombre = @NomCargo
          AND @MontoCargo > 0

        -- cierra el estado de cuenta con el saldo final y los intereses del mes
        UPDATE dbo.Estado_Cuenta
        SET
            saldo_final = @NuevoSaldoFinal,
            interesesAcumulados = CASE WHEN @MontoIntereses > 0 THEN @MontoIntereses ELSE 0 END
        WHERE Id = @IdEstadoCuenta

        -- abre el estado de cuenta del mes siguiente con el saldo que dejo el cierre
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
        VALUES (
            @in_IdCuenta, 
            @FechaInicioNuevo, 
            @FechaFinNuevo, 
            @NuevoSaldoFinal, 
            @NuevoSaldoFinal, 
            @NuevoSaldoFinal,
            0.00, 
            0, 
            0, 
            0, 
            0,
            0, 
            0
        )

        COMMIT TRANSACTION tCerrarEstadoCuenta
    END TRY
    BEGIN CATCH
        -- ante cualquier error se deshace el cierre completo de esta cuenta
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION
        END

        SET @out_ResultCode = 50000
    END CATCH
END
GO