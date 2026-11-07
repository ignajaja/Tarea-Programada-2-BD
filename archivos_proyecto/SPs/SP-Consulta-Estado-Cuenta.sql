CREATE OR ALTER PROCEDURE dbo.sp_ConsultarEstadosDeCuenta
    @in_Username VARCHAR(64),          -- usuario que realiza la consulta
    @in_IdCuenta INT,                  -- id de la cuenta a consultar
    @in_IP VARCHAR(64) = '0.0.0.0'     -- ip por defecto si no se recibe desde views.py
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- obtener el id y privilegios del usuario actual
    DECLARE @IdUsuario INT;            -- id numérico del usuario
    DECLARE @EsAdmin BIT = 0;          -- privilegios de administrador
    
    SELECT @IdUsuario = Id, @EsAdmin = EsAdministrador 
    FROM Usuario 
    WHERE Username = @in_Username;

    -- consultar los últimos estados de cuenta
    SELECT TOP 8 
        c.NumeroCuenta,
        ec.fechaInicio AS FechaInicio,
        ec.fechafin AS FechaFin,
        ec.saldoinicial AS SaldoInicial,
        ec.saldoMinimo AS SaldoMinimo,
        ec.saldo_final AS SaldoFinal,
        ec.interesesAcumulados AS InteresesAcumulados,
        ec.cantRetiros AS CantRetiros,
        ec.cantDepositos AS CantDepositos,
        ec.cantSinpeEntrantes AS CantSinpeEntrantes,
        ec.cantSinpeSalientes AS CantSinpeSalientes
    FROM Estado_Cuenta ec
    INNER JOIN Cuenta c ON ec.IdCuenta = c.Id
    WHERE ec.IdCuenta = @in_IdCuenta
      AND (@EsAdmin = 1 OR ec.IdCuenta IN (
          SELECT IdCuenta 
          FROM Usuarios_Ver 
          WHERE IdUsuario = @IdUsuario
      ))
    ORDER BY ec.fechafin DESC;

    -- registrar la consulta en la bitácora (tipo de operación 7)
    INSERT INTO Bitacora (IdUsuario, IdTipoOperacion, IP, FechaHora)
    VALUES (@IdUsuario, 7, @in_IP, GETDATE());
END;
GO