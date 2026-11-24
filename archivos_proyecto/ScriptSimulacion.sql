USE [TareaProgramada2]
GO
/*
script de la corrida de la simulacion y de verificacion de los datos (Tres.1 del enunciado)

simulacion completa del 2026-03-01 al 2026-06-30 y revision de que los datos coincidan
las consultas de cuadre deben devolver 0 filas
*/

DECLARE @r INT; -- codigo que devuelve cada sp
DECLARE @inicio DATETIME = GETDATE(); -- hora de inicio de la corrida, para medir el tiempo total
DECLARE @MovimientosAntes INT; -- movimientos despues de la primera corrida
DECLARE @MovimientosDespues INT; -- movimientos despues de correr la simulacion otra vez

DECLARE @resultados TABLE (
 Paso VARCHAR(64)
 , Esperado INT
 , Obtenido INT
);

-- 1 corrida completa
EXEC dbo.sp_LimpiarBaseDatos @out_ResultCode = @r OUTPUT;
INSERT INTO @resultados VALUES ('1 sp_LimpiarBaseDatos', 0, @r);

EXEC dbo.sp_CargarCatalogos @out_ResultCode = @r OUTPUT;
INSERT INTO @resultados VALUES ('2 sp_CargarCatalogos', 0, @r);

EXEC dbo.sp_EjecutarSimulacion @out_ResultCode = @r OUTPUT;
INSERT INTO @resultados VALUES ('3 sp_EjecutarSimulacion', 0, @r);

-- correrla otra vez no debe hacer nada, todas las fechas ya estan procesadas
SELECT @MovimientosAntes = COUNT(*) FROM dbo.Movimiento;

EXEC dbo.sp_EjecutarSimulacion @out_ResultCode = @r OUTPUT;
INSERT INTO @resultados VALUES ('4 sp_EjecutarSimulacion otra vez', 0, @r);

SELECT @MovimientosDespues = COUNT(*) FROM dbo.Movimiento;
INSERT INTO @resultados VALUES ('5 movimientos que se agregaron en la segunda corrida', 0, @MovimientosDespues - @MovimientosAntes);

-- resultado de cada paso, esperado y obtenido deben ser iguales
SELECT R.Paso
 , R.Esperado
 , R.Obtenido
 , DATEDIFF(SECOND, @inicio, GETDATE()) AS SegundosTotales
FROM @resultados AS R;

-- 2 resumen de los datos cargados
-- esperado segun los xml: fechas procesadas 122, persona 16, cuenta 10, beneficiario 11, usuario 11, usuarios ver 11, comprobante 100
-- estado de cuenta 37, que son 27 cerrados y 10 abiertos
SELECT 'Fechas procesadas' AS Dato, COUNT(*) AS Cantidad FROM dbo.Simulacion_Control WHERE Estado = 'Procesada'
UNION ALL SELECT 'Persona', COUNT(*) FROM dbo.Persona
UNION ALL SELECT 'Cuenta', COUNT(*) FROM dbo.Cuenta
UNION ALL SELECT 'Beneficiario', COUNT(*) FROM dbo.Beneficiario
UNION ALL SELECT 'Usuario', COUNT(*) FROM dbo.Usuario
UNION ALL SELECT 'Usuarios_Ver', COUNT(*) FROM dbo.Usuarios_Ver
UNION ALL SELECT 'Movimiento', COUNT(*) FROM dbo.Movimiento
UNION ALL SELECT 'Comprobante', COUNT(*) FROM dbo.Comprobante
UNION ALL SELECT 'Estado_Cuenta total', COUNT(*) FROM dbo.Estado_Cuenta;

-- estados cerrados y abiertos, un estado esta cerrado si ya existe el que empieza el dia siguiente
SELECT COUNT(EC.Id) AS Total
 , COUNT(Siguiente.Id) AS Cerrados
 , COUNT(EC.Id) - COUNT(Siguiente.Id) AS Abiertos
FROM dbo.Estado_Cuenta AS EC
LEFT JOIN dbo.Estado_Cuenta AS Siguiente ON Siguiente.IdCuenta = EC.IdCuenta
 AND Siguiente.fechaInicio = DATEADD(day, 1, EC.fechafin);

-- 3 movimientos por tipo
SELECT TM.Nombre AS Tipo
 , COUNT(*) AS Cantidad
 , SUM(M.Monto) AS MontoTotal
FROM dbo.Movimiento AS M
INNER JOIN dbo.Tipos_Movimiento AS TM ON TM.Id = M.IdTipoMovimiento
GROUP BY TM.Nombre
ORDER BY TM.Nombre;

-- 4 saldo final de cada cuenta con el simbolo de su moneda
SELECT C.NumeroCuenta
 , TMon.Simbolo
 , C.Saldo
FROM dbo.Cuenta AS C
INNER JOIN dbo.Tipo_Cuenta_Ahorros AS TCA ON TCA.Id = C.IdTipoCuenta
INNER JOIN dbo.Tipo_Moneda AS TMon ON TMon.Id = TCA.IdTipoMoneda
ORDER BY C.NumeroCuenta;

-- 5 estados de cuenta de todas las cuentas en orden cronologico
SELECT C.NumeroCuenta
 , EC.fechaInicio
 , EC.fechafin
 , EC.saldoinicial
 , EC.saldoMinimo
 , EC.interesesAcumulados
 , EC.saldo_final
 , EC.cantOperacionesATM
 , EC.cantOperacionesHumano
 , EC.cantSinpeEntrantes
 , EC.cantSinpeSalientes
FROM dbo.Estado_Cuenta AS EC
INNER JOIN dbo.Cuenta AS C ON C.Id = EC.IdCuenta
ORDER BY C.NumeroCuenta, EC.fechaInicio;

-- 6 comisiones, multas, cargos e intereses que genero la simulacion
SELECT C.NumeroCuenta
 , M.Fecha
 , TM.Nombre AS Tipo
 , M.Monto
 , M.Descripcion
FROM dbo.Movimiento AS M
INNER JOIN dbo.Cuenta AS C ON C.Id = M.IdCuenta
INNER JOIN dbo.Tipos_Movimiento AS TM ON TM.Id = M.IdTipoMovimiento
WHERE TM.flagGeneraComprobante = 0
ORDER BY C.NumeroCuenta, M.Fecha, M.Id;

-- cuadre A el saldo de la cuenta es el nuevo saldo de su ultimo movimiento (0 filas)
SELECT C.NumeroCuenta
 , C.Saldo
 , M.NuevoSaldo AS SaldoUltimoMovimiento
FROM dbo.Cuenta AS C
INNER JOIN dbo.Movimiento AS M ON M.Id = (
 SELECT MAX(M2.Id) FROM dbo.Movimiento AS M2 WHERE M2.IdCuenta = C.Id
)
WHERE C.Saldo <> M.NuevoSaldo;

-- cuadre B cada nuevo saldo es el saldo anterior mas el monto si es credito o menos el monto si es debito (0 filas)
-- el saldo anterior de la primera operacion de una cuenta es 0 porque las cuentas del xml inician en 0
SELECT X.NumeroCuenta
 , X.IdMovimiento
 , X.SaldoAnterior
 , X.Monto
 , X.NuevoSaldo
FROM (
 SELECT C.NumeroCuenta
  , M.Id AS IdMovimiento
  , M.Monto
  , M.NuevoSaldo
  , TM.Accion
  , ISNULL((
   SELECT P.NuevoSaldo FROM dbo.Movimiento AS P WHERE P.Id = (
    SELECT MAX(P2.Id) FROM dbo.Movimiento AS P2 WHERE P2.IdCuenta = M.IdCuenta AND P2.Id < M.Id
   )
  ), 0) AS SaldoAnterior
 FROM dbo.Movimiento AS M
 INNER JOIN dbo.Cuenta AS C ON C.Id = M.IdCuenta
 INNER JOIN dbo.Tipos_Movimiento AS TM ON TM.Id = M.IdTipoMovimiento
) AS X
WHERE (X.Accion = 'Credito' AND X.NuevoSaldo <> X.SaldoAnterior + X.Monto)
 OR (X.Accion = 'Debito' AND X.NuevoSaldo <> X.SaldoAnterior - X.Monto);

-- cuadre C saldo inicial mas creditos menos debitos es el saldo final de cada estado (0 filas)
SELECT C.NumeroCuenta
 , EC.fechaInicio
 , EC.saldoinicial
 , EC.saldo_final
FROM dbo.Estado_Cuenta AS EC
INNER JOIN dbo.Cuenta AS C ON C.Id = EC.IdCuenta
WHERE EC.saldo_final <> EC.saldoinicial
 + ISNULL((
  SELECT SUM(M.Monto) FROM dbo.Movimiento AS M
  INNER JOIN dbo.Tipos_Movimiento AS TM ON TM.Id = M.IdTipoMovimiento
  WHERE M.IdCuenta = EC.IdCuenta AND M.Fecha >= EC.fechaInicio AND M.Fecha <= EC.fechafin AND TM.Accion = 'Credito'
 ), 0)
 - ISNULL((
  SELECT SUM(M.Monto) FROM dbo.Movimiento AS M
  INNER JOIN dbo.Tipos_Movimiento AS TM ON TM.Id = M.IdTipoMovimiento
  WHERE M.IdCuenta = EC.IdCuenta AND M.Fecha >= EC.fechaInicio AND M.Fecha <= EC.fechafin AND TM.Accion = 'Debito'
 ), 0);

-- cuadre D cada estado empieza el dia despues del anterior y con su saldo final (0 filas)
-- se compara cada estado con el siguiente de la misma cuenta, el que empieza el dia despues de que termina
SELECT C.NumeroCuenta
 , ECA.fechafin AS FechaFinAnterior
 , ECA.saldo_final AS SaldoFinalAnterior
 , ECS.fechaInicio
 , ECS.saldoinicial
FROM dbo.Estado_Cuenta AS ECA
INNER JOIN dbo.Estado_Cuenta AS ECS ON ECS.IdCuenta = ECA.IdCuenta
 AND ECS.fechaInicio = DATEADD(day, 1, ECA.fechafin)
INNER JOIN dbo.Cuenta AS C ON C.Id = ECA.IdCuenta
WHERE ECS.saldoinicial <> ECA.saldo_final;

-- cuadre E cada cuenta tiene exactamente un estado abierto y su saldo final es el saldo de la cuenta (0 filas)
SELECT C.NumeroCuenta
 , COUNT(A.IdCuenta) AS EstadosAbiertos
 , C.Saldo
FROM dbo.Cuenta AS C
LEFT JOIN (
 SELECT EC.IdCuenta, EC.saldo_final
 FROM dbo.Estado_Cuenta AS EC
 LEFT JOIN dbo.Estado_Cuenta AS Siguiente ON Siguiente.IdCuenta = EC.IdCuenta
  AND Siguiente.fechaInicio = DATEADD(day, 1, EC.fechafin)
 WHERE Siguiente.Id IS NULL
) AS A ON A.IdCuenta = C.Id
GROUP BY C.Id, C.NumeroCuenta, C.Saldo
HAVING COUNT(A.IdCuenta) <> 1
 OR MAX(A.saldo_final) <> C.Saldo;

-- cuadre F cada movimiento de un tipo que genera comprobante tiene su comprobante y los demas no (0 filas)
SELECT M.Id
 , TM.Nombre
 , M.IdComprobante
FROM dbo.Movimiento AS M
INNER JOIN dbo.Tipos_Movimiento AS TM ON TM.Id = M.IdTipoMovimiento
WHERE (TM.flagGeneraComprobante = 1 AND M.IdComprobante IS NULL)
 OR (TM.flagGeneraComprobante = 0 AND M.IdComprobante IS NOT NULL);

-- movimientos rechazados y errores de la corrida, esperado ninguno si todos los movimientos del xml son validos
SELECT BS.FechaOperacion
 , BS.NumeroCuenta
 , BS.TipoMovimiento
 , BS.Monto
 , BS.CodigoError
 , BS.Mensaje
FROM dbo.Bitacora_Simulacion AS BS
ORDER BY BS.Id;
GO