USE [TareaProgramada2]
GO
/****** Objeto: StoredProcedure [dbo].[sp_EjecutarSimulacion] Fecha de script: 11/19/2026 10:59:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_EjecutarSimulacion]
 @out_ResultCode INT OUTPUT -- 0 exito, 50000 error (el detalle queda en Bitacora_Simulacion)
AS
/*
ejemplo de ejecucion
 DECLARE @resultado INT
 EXEC dbo.sp_EjecutarSimulacion @out_ResultCode = @resultado OUTPUT
 SELECT @resultado AS ResultCode
 SELECT SC.FechaOperacion, SC.Estado, SC.UltimoMovimientoProcesado FROM dbo.Simulacion_Control AS SC ORDER BY SC.FechaOperacion
 SELECT BS.Id, BS.FechaOperacion, BS.NumeroCuenta, BS.TipoMovimiento, BS.Monto, BS.CodigoError, BS.Mensaje FROM dbo.Bitacora_Simulacion AS BS ORDER BY BS.Id

si el proceso falla se puede volver a ejecutar, continua desde la ultima fecha y el ultimo movimiento procesados
las fechas ya procesadas no se vuelven a ejecutar
*/
BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  -- inicia en exito
  SET @out_ResultCode = 0;

  -- contenido del xml de operaciones
  DECLARE @DatosXML XML;

  -- primera y ultima fecha del xml, la simulacion recorre todas las fechas entre ambas
  DECLARE @FechaMin DATE;
  DECLARE @FechaMax DATE;

  -- fechas pendientes de procesar en orden ascendente, incluye las fechas sin datos en el xml
  DECLARE @Fechas TABLE (
   RowID INT IDENTITY(1,1) PRIMARY KEY
   , FechaOp DATE
  );

  -- datos del xml cargados una sola vez, cada fila queda con la fecha de operacion a la que pertenece
  DECLARE @Personas TABLE (
   Fecha DATE
   , IdTipoDoc INT
   , ValorDocumentoIdentidad VARCHAR(32)
   , Nombre VARCHAR(128)
   , FechaNacimiento DATE
   , Email VARCHAR(128)
   , Telefono1 VARCHAR(32)
   , Telefono2 VARCHAR(32)
  );
  DECLARE @Cuentas TABLE (
   Fecha DATE
   , ValorDocumentoCliente VARCHAR(32)
   , IdTipoCuenta INT
   , NumeroCuenta VARCHAR(32)
   , FechaCreacion DATE
   , Saldo DECIMAL(18,2)
  );
  DECLARE @Beneficiarios TABLE (
   Fecha DATE
   , NumeroCuenta VARCHAR(32)
   , ValorDocumentoBeneficiario VARCHAR(32)
   , IdParentesco INT
   , Porcentaje INT
  );
  DECLARE @Usuarios TABLE (
   Fecha DATE
   , Username VARCHAR(64)
   , Pass VARCHAR(128)
   , EsAdministrador BIT
   , ValorDocumento VARCHAR(32)
  );
  DECLARE @UsuariosVer TABLE (
   Fecha DATE
   , Username VARCHAR(64)
   , NumeroCuenta VARCHAR(32)
  );
  DECLARE @Movimientos TABLE (
   Id INT IDENTITY(1,1) PRIMARY KEY -- posicion del movimiento en el xml, es la llave que se guarda para reiniciar
   , Fecha DATE
   , CodigoCuenta VARCHAR(32)
   , TipoMov VARCHAR(64)
   , Monto DECIMAL(18,2)
   , Descripcion VARCHAR(256)
  );

  -- cuentas cuyo estado de cuenta cierra en la fecha que se esta procesando
  DECLARE @CuentasCierre TABLE (
   IdCuenta INT PRIMARY KEY
  );

  -- control del ciclo de fechas
  DECLARE @Fila INT = 1; -- fila actual de @Fechas
  DECLARE @FechaGenerada DATE; -- fecha que se agrega al generar el calendario
  DECLARE @TotalFechas INT; -- cantidad de fechas pendientes
  DECLARE @FechaActual DATE; -- fecha que se esta procesando
  DECLARE @Pendientes INT; -- fechas anteriores a la actual que no estan procesadas, debe ser 0

  -- control del ciclo de movimientos
  DECLARE @UltimoMov INT; -- id del ultimo movimiento ya procesado de la fecha, desde ahi se reinicia
  DECLARE @IdMovActual INT; -- id en @Movimientos del movimiento que se esta aplicando
  DECLARE @CuentaMov VARCHAR(32); -- cuenta del movimiento actual
  DECLARE @TipoMov VARCHAR(64); -- tipo del movimiento actual
  DECLARE @MontoMov DECIMAL(18,2); -- monto del movimiento actual
  DECLARE @DescMov VARCHAR(256); -- descripcion del movimiento actual
  DECLARE @ResMov INT; -- codigo que devuelve sp_AplicarMovimiento

  -- control del ciclo de cierres
  DECLARE @IdCuentaCierre INT; -- cuenta a la que se le cierra el estado
  DECLARE @ResCierre INT; -- codigo que devuelve sp_CerrarYCrearEstadoCuenta

  -- banderas de existencia, se calculan antes de insertar para no duplicar datos
  DECLARE @flagFechaProcesada BIT; -- 1 si la fecha ya esta procesada en el control
  DECLARE @flagFechaEnControl BIT; -- 1 si la fecha ya tiene fila en el control

  -- mensajes de los movimientos rechazados por una regla de negocio
  DECLARE @Mensajes TABLE (
   Codigo INT -- codigo que devuelve sp_AplicarMovimiento
   , Mensaje VARCHAR(256) -- texto que se guarda en la bitacora de la simulacion
  );

  -- carga los mensajes de error de los movimientos
  INSERT INTO @Mensajes (Codigo, Mensaje)
  VALUES
   (50001, 'Monto invalido')
   , (50002, 'La cuenta no existe')
   , (50003, 'El tipo de movimiento no existe')
   , (50004, 'La cuenta no tiene estado de cuenta abierto en esa fecha')
   , (50005, 'Saldo insuficiente');

  -- lee el archivo xml de operaciones
  SELECT @DatosXML = CONVERT(XML, X.BulkColumn)
  FROM OPENROWSET(BULK 'C:\archivoBDD\OperacionesTarea3.xml', SINGLE_BLOB) AS X;

  -- obtiene la primera y la ultima fecha del xml
  SELECT
   @FechaMin = MIN(T.Nodo.value('@Fecha', 'DATE'))
   , @FechaMax = MAX(T.Nodo.value('@Fecha', 'DATE'))
  FROM @DatosXML.nodes('/Operaciones/FechaOperacion') AS T(Nodo);

  -- genera todas las fechas entre la primera y la ultima, solo las que aun no estan procesadas
  SET @FechaGenerada = @FechaMin;

  WHILE @FechaGenerada <= @FechaMax
  BEGIN
   -- marca si la fecha ya fue procesada en una corrida anterior
   SET @flagFechaProcesada = 0;

   SELECT @flagFechaProcesada = 1
   FROM dbo.Simulacion_Control AS SC
   WHERE SC.FechaOperacion = @FechaGenerada
   AND SC.Estado = 'Procesada';

   INSERT INTO @Fechas (FechaOp)
   SELECT @FechaGenerada
   WHERE @flagFechaProcesada = 0;

   SET @FechaGenerada = DATEADD(day, 1, @FechaGenerada);
  END;

  -- carga las personas del xml
  INSERT INTO @Personas (
   Fecha
   , IdTipoDoc
   , ValorDocumentoIdentidad
   , Nombre
   , FechaNacimiento
   , Email
   , Telefono1
   , Telefono2
  )
  SELECT
   T.Nodo.value('../@Fecha', 'DATE')
   , T.Nodo.value('@TipoDocuIdentidad', 'INT')
   , T.Nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(32)')
   , T.Nodo.value('@Nombre', 'VARCHAR(128)')
   , T.Nodo.value('@FechaNacimiento', 'DATE')
   , T.Nodo.value('@Email', 'VARCHAR(128)')
   , T.Nodo.value('@telefono1', 'VARCHAR(32)')
   , T.Nodo.value('@telefono2', 'VARCHAR(32)')
  FROM @DatosXML.nodes('/Operaciones/FechaOperacion/Persona') AS T(Nodo);

  -- carga las cuentas del xml
  INSERT INTO @Cuentas (
   Fecha
   , ValorDocumentoCliente
   , IdTipoCuenta
   , NumeroCuenta
   , FechaCreacion
   , Saldo
  )
  SELECT
   T.Nodo.value('../@Fecha', 'DATE')
   , T.Nodo.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(32)')
   , T.Nodo.value('@TipoCuentaId', 'INT')
   , T.Nodo.value('@NumeroCuenta', 'VARCHAR(32)')
   , T.Nodo.value('@FechaCreacion', 'DATE')
   , T.Nodo.value('@Saldo', 'DECIMAL(18,2)')
  FROM @DatosXML.nodes('/Operaciones/FechaOperacion/Cuenta') AS T(Nodo);

  -- carga los beneficiarios del xml
  INSERT INTO @Beneficiarios (
   Fecha
   , NumeroCuenta
   , ValorDocumentoBeneficiario
   , IdParentesco
   , Porcentaje
  )
  SELECT
   T.Nodo.value('../@Fecha', 'DATE')
   , T.Nodo.value('@NumeroCuenta', 'VARCHAR(32)')
   , T.Nodo.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(32)')
   , T.Nodo.value('@IdParentezco', 'INT')
   , T.Nodo.value('@Porcentaje', 'INT')
  FROM @DatosXML.nodes('/Operaciones/FechaOperacion/Beneficiario') AS T(Nodo);

  -- carga los usuarios del xml
  INSERT INTO @Usuarios (
   Fecha
   , Username
   , Pass
   , EsAdministrador
   , ValorDocumento
  )
  SELECT
   T.Nodo.value('../@Fecha', 'DATE')
   , T.Nodo.value('@User', 'VARCHAR(64)')
   , T.Nodo.value('@Pass', 'VARCHAR(128)')
   , T.Nodo.value('@EsAdministrador', 'BIT')
   , T.Nodo.value('@ValorDocId', 'VARCHAR(32)')
  FROM @DatosXML.nodes('/Operaciones/FechaOperacion/Usuario') AS T(Nodo);

  -- carga los permisos de visualizacion del xml
  INSERT INTO @UsuariosVer (
   Fecha
   , Username
   , NumeroCuenta
  )
  SELECT
   T.Nodo.value('../@Fecha', 'DATE')
   , T.Nodo.value('@User', 'VARCHAR(64)')
   , T.Nodo.value('@NumeroCuenta', 'VARCHAR(32)')
  FROM @DatosXML.nodes('/Operaciones/FechaOperacion/UsuarioPuedeVer') AS T(Nodo);

  -- carga los movimientos del xml, el id identity conserva el orden en que vienen en el xml
  INSERT INTO @Movimientos (
   Fecha
   , CodigoCuenta
   , TipoMov
   , Monto
   , Descripcion
  )
  SELECT
   T.Nodo.value('../@Fecha', 'DATE')
   , T.Nodo.value('@CodigoCuenta', 'VARCHAR(32)')
   , T.Nodo.value('@Tipo', 'VARCHAR(64)')
   , T.Nodo.value('@Monto', 'DECIMAL(18,2)')
   , T.Nodo.value('@Descripcion', 'VARCHAR(256)')
  FROM @DatosXML.nodes('/Operaciones/FechaOperacion/Movimientos') AS T(Nodo);

  -- cantidad de fechas por procesar
  SELECT @TotalFechas = COUNT(*)
  FROM @Fechas AS F;

  -- recorre las fechas de forma consecutiva
  WHILE @Fila <= @TotalFechas
  BEGIN
   -- toma la fecha de esta iteracion
   SELECT @FechaActual = F.FechaOp
   FROM @Fechas AS F
   WHERE F.RowID = @Fila;

   -- cuenta las fechas anteriores a la actual que no estan procesadas, si hay alguna se detiene
   SELECT @Pendientes = DATEDIFF(day, @FechaMin, @FechaActual) - COUNT(*)
   FROM dbo.Simulacion_Control AS SC
   WHERE SC.Estado = 'Procesada'
   AND SC.FechaOperacion < @FechaActual;

   IF @Pendientes > 0
   BEGIN
    INSERT INTO dbo.Bitacora_Simulacion (FechaOperacion, CodigoError, Mensaje)
    VALUES (@FechaActual, 50000, 'Se intento procesar una fecha sin haber procesado la fecha anterior');

    SET @out_ResultCode = 50000;
    RETURN;
   END;

   -- registra la fecha en el control, si ya existe (reinicio) se conserva su ultimo movimiento
   SET @flagFechaEnControl = 0;

   SELECT @flagFechaEnControl = 1
   FROM dbo.Simulacion_Control AS SC
   WHERE SC.FechaOperacion = @FechaActual;

   INSERT INTO dbo.Simulacion_Control (
    FechaOperacion
    , Estado
   )
   SELECT @FechaActual
    , 'En proceso'
   WHERE @flagFechaEnControl = 0;

   -- lee desde que movimiento se debe continuar
   SELECT @UltimoMov = SC.UltimoMovimientoProcesado
   FROM dbo.Simulacion_Control AS SC
   WHERE SC.FechaOperacion = @FechaActual;

   -- paso 1 personas, cuentas, beneficiarios y usuarios del dia en una transaccion
   BEGIN TRANSACTION tEntidadesDia;

   -- inserta las personas nuevas del dia
   INSERT INTO dbo.Persona (
    IdTipoDoc
    , ValorDocumentoIdentidad
    , Nombre
    , FechaNacimiento
    , Email
    , telefono1
    , telefono2
   )
   SELECT X.IdTipoDoc
    , X.ValorDocumentoIdentidad
    , X.Nombre
    , X.FechaNacimiento
    , X.Email
    , X.Telefono1
    , X.Telefono2
   FROM @Personas AS X
   LEFT JOIN dbo.Persona AS P ON P.ValorDocumentoIdentidad = X.ValorDocumentoIdentidad
   WHERE X.Fecha = @FechaActual
   AND P.Id IS NULL;

   -- inserta las cuentas del dia mapeando el documento del cliente al id de la persona
   -- el trigger crea el primer estado de cuenta de cada una
   INSERT INTO dbo.Cuenta (
    IdTipoCuenta
    , NumeroCuenta
    , FechaCreacion
    , Saldo
    , IdPersona
   )
   SELECT X.IdTipoCuenta
    , X.NumeroCuenta
    , X.FechaCreacion
    , X.Saldo
    , P.Id
   FROM @Cuentas AS X
   INNER JOIN dbo.Persona AS P ON P.ValorDocumentoIdentidad = X.ValorDocumentoCliente
   LEFT JOIN dbo.Cuenta AS C ON C.NumeroCuenta = X.NumeroCuenta
   WHERE X.Fecha = @FechaActual
   AND C.Id IS NULL;

   -- inserta los beneficiarios del dia mapeando numero de cuenta y documento a sus ids
   INSERT INTO dbo.Beneficiario (
    IdCuenta
    , IdPersonaBeneficiario
    , IdParentesco
    , Porcentaje
    , Activo
   )
   SELECT C.Id
    , P.Id
    , X.IdParentesco
    , X.Porcentaje
    , 1
   FROM @Beneficiarios AS X
   INNER JOIN dbo.Cuenta AS C ON C.NumeroCuenta = X.NumeroCuenta
   INNER JOIN dbo.Persona AS P ON P.ValorDocumentoIdentidad = X.ValorDocumentoBeneficiario
   LEFT JOIN dbo.Beneficiario AS B ON B.IdCuenta = C.Id
    AND B.IdPersonaBeneficiario = P.Id
   WHERE X.Fecha = @FechaActual
   AND B.Id IS NULL;

   -- inserta los usuarios del dia mapeando el documento al id de la persona
   INSERT INTO dbo.Usuario (
    Username
    , Pass
    , EsAdministrador
    , IdPersona
   )
   SELECT X.Username
    , X.Pass
    , X.EsAdministrador
    , P.Id
   FROM @Usuarios AS X
   INNER JOIN dbo.Persona AS P ON P.ValorDocumentoIdentidad = X.ValorDocumento
   LEFT JOIN dbo.Usuario AS U ON U.Username = X.Username
   WHERE X.Fecha = @FechaActual
   AND U.Id IS NULL;

   -- inserta los permisos de visualizacion mapeando usuario y cuenta a sus ids
   INSERT INTO dbo.Usuarios_Ver (
    IdUsuario
    , IdCuenta
   )
   SELECT U.Id
    , C.Id
   FROM @UsuariosVer AS X
   INNER JOIN dbo.Usuario AS U ON U.Username = X.Username
   INNER JOIN dbo.Cuenta AS C ON C.NumeroCuenta = X.NumeroCuenta
   LEFT JOIN dbo.Usuarios_Ver AS UV ON UV.IdUsuario = U.Id
    AND UV.IdCuenta = C.Id
   WHERE X.Fecha = @FechaActual
   AND UV.Id IS NULL;

   COMMIT TRANSACTION tEntidadesDia;

   -- paso 2 movimientos del dia, cada uno se aplica en su propia transaccion dentro de sp_AplicarMovimiento
   -- toma el primer movimiento de la fecha posterior al ultimo procesado
   SELECT @IdMovActual = MIN(M.Id)
   FROM @Movimientos AS M
   WHERE M.Fecha = @FechaActual
   AND M.Id > @UltimoMov;

   WHILE @IdMovActual IS NOT NULL
   BEGIN
    -- toma los datos del movimiento actual
    SELECT
     @CuentaMov = M.CodigoCuenta
     , @TipoMov = M.TipoMov
     , @MontoMov = M.Monto
     , @DescMov = M.Descripcion
    FROM @Movimientos AS M
    WHERE M.Id = @IdMovActual;

    -- aplica el movimiento
    EXEC dbo.sp_AplicarMovimiento
     @in_NumeroCuenta = @CuentaMov
     , @in_NombreTipoMovimiento = @TipoMov
     , @in_Monto = @MontoMov
     , @in_Descripcion = @DescMov
     , @in_FechaOperacion = @FechaActual
     , @in_IdMovimientoXml = @IdMovActual
     , @out_ResultCode = @ResMov OUTPUT;

    -- si el movimiento fue rechazado por una regla de negocio queda registrado y la simulacion continua
    INSERT INTO dbo.Bitacora_Simulacion (
     FechaOperacion
     , NumeroCuenta
     , TipoMovimiento
     , Monto
     , CodigoError
     , Mensaje
    )
    SELECT
     @FechaActual
     , @CuentaMov
     , @TipoMov
     , @MontoMov
     , @ResMov
     , MS.Mensaje
    FROM @Mensajes AS MS
    WHERE MS.Codigo = @ResMov;

    -- los movimientos rechazados tambien se marcan como procesados, los aplicados ya se marcaron dentro del sp
    UPDATE dbo.Simulacion_Control
    SET UltimoMovimientoProcesado = @IdMovActual
    WHERE FechaOperacion = @FechaActual
    AND @ResMov <> 50000;

    -- un error de base de datos detiene la simulacion
    IF @ResMov = 50000
    BEGIN
     INSERT INTO dbo.Bitacora_Simulacion (FechaOperacion, NumeroCuenta, TipoMovimiento, Monto, CodigoError, Mensaje)
     VALUES (@FechaActual, @CuentaMov, @TipoMov, @MontoMov, 50000, 'Error de base de datos al aplicar un movimiento');

     SET @out_ResultCode = 50000;
     RETURN;
    END;

    -- siguiente movimiento de la fecha
    SELECT @IdMovActual = MIN(M.Id)
    FROM @Movimientos AS M
    WHERE M.Fecha = @FechaActual
    AND M.Id > @IdMovActual;
   END;

   -- paso 3 cierre de estados de cuenta, se buscan las cuentas cuyo estado termina hoy y no se han cerrado
   DELETE FROM @CuentasCierre;

   INSERT INTO @CuentasCierre (IdCuenta)
   SELECT EC.IdCuenta
   FROM dbo.Estado_Cuenta AS EC
   LEFT JOIN dbo.Estado_Cuenta AS Siguiente ON Siguiente.IdCuenta = EC.IdCuenta
    AND Siguiente.fechaInicio = DATEADD(day, 1, EC.fechafin)
   WHERE EC.fechafin = @FechaActual
   AND Siguiente.Id IS NULL;

   -- recorre las cuentas de menor a mayor id, cada cierre es una transaccion propia
   SELECT @IdCuentaCierre = MIN(CC.IdCuenta) FROM @CuentasCierre AS CC;

   WHILE @IdCuentaCierre IS NOT NULL
   BEGIN
    EXEC dbo.sp_CerrarYCrearEstadoCuenta
     @in_IdCuenta = @IdCuentaCierre
     , @in_FechaProceso = @FechaActual
     , @out_ResultCode = @ResCierre OUTPUT;

    IF @ResCierre > 0
    BEGIN
     INSERT INTO dbo.Bitacora_Simulacion (FechaOperacion, CodigoError, Mensaje)
     VALUES (@FechaActual, 50000, 'Error al cerrar y abrir el estado de cuenta');

     SET @out_ResultCode = 50000;
     RETURN;
    END;

    SELECT @IdCuentaCierre = MIN(CC.IdCuenta)
    FROM @CuentasCierre AS CC
    WHERE CC.IdCuenta > @IdCuentaCierre;
   END;

   -- paso 4 marca la fecha como procesada
   UPDATE dbo.Simulacion_Control
   SET Estado = 'Procesada'
    , FechaHoraFin = GETDATE()
   WHERE FechaOperacion = @FechaActual;

   SET @Fila = @Fila + 1;
  END;
 END TRY
 BEGIN CATCH
  -- deshace lo que estuviera abierto, lo ya confirmado queda y la simulacion se puede reiniciar
  IF @@TRANCOUNT > 0
  BEGIN
   ROLLBACK TRANSACTION;
  END;

  -- deja el error registrado, la variable recorta el mensaje al tamaño de la columna
  DECLARE @MensajeError VARCHAR(256) = ERROR_MESSAGE(); -- texto del error de base de datos

  INSERT INTO dbo.Bitacora_Simulacion (
   FechaOperacion
   , NumeroCuenta
   , TipoMovimiento
   , Monto
   , CodigoError
   , Mensaje
  )
  VALUES (
   @FechaActual
   , NULL
   , NULL
   , NULL
   , 50000
   , @MensajeError
  );

  SET @out_ResultCode = 50000;
 END CATCH;
END;
