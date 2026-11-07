CREATE OR ALTER PROCEDURE dbo.sp_CargarNoCatalogos
    @outResultCode INT OUTPUT -- código de resultado de la operación (0 éxito, otro error)
AS
/*
Ejemplo de ejecución:
    DECLARE @resultado INT;
    EXEC dbo.spCargarNoCatalogos @outResultCode = @resultado OUTPUT;
    SELECT @resultado AS ResultCode;
*/
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    BEGIN TRY
        DECLARE @datos XML;          -- almacena el contenido del archivo xml
        SET @outResultCode = 0;      -- inicializar código de éxito por defecto

        -- tablas temporales para alojar temporalmente los datos del xml
        DECLARE @Persona TABLE (
            IdTipoDoc INT,
            ValorDocumentoIdentidad VARCHAR(32),
            Nombre VARCHAR(64),
            FechaNacimiento DATE,
            Email VARCHAR(64),
            telefono1 VARCHAR(64),
            telefono2 VARCHAR(64)
        );

        DECLARE @Usuario TABLE (
            Username VARCHAR(64),
            Pass VARCHAR(64),
            EsAdministrador BIT,
            ValorDocumento VARCHAR(32)
        );

        DECLARE @Cuenta TABLE (
            NumeroCuenta VARCHAR(20),
            ValorDocumento VARCHAR(32),
            IdTipoCuenta INT,
            FechaCreacion DATE,
            Saldo DECIMAL(18,2)
        );

        DECLARE @Beneficiario TABLE (
            NumeroCuenta VARCHAR(20),
            ValorDocumento VARCHAR(32),
            IdParentesco INT,
            Porcentaje INT
        );

        DECLARE @EstadoCuenta TABLE (
            NumeroCuenta VARCHAR(20),
            fechaInicio DATE,
            fechafin DATE,
            saldoinicial DECIMAL(18,2),
            saldoMinimo DECIMAL(18,2),
            saldo_final DECIMAL(18,2),
            interesesAcumulados DECIMAL(18,2),
            cantRetiros INT,
            cantDepositos INT,
            cantSinpeEntrantes INT,
            cantSinpeSalientes INT
        );

        DECLARE @UsuarioPuedeVer TABLE (
            Username VARCHAR(64),
            NumeroCuenta VARCHAR(20)
        );

        -- leer el archivo xml de datos no catálogos mediante openrowset
        SELECT @datos = X.BulkColumn
        FROM OPENROWSET(BULK 'C:\archivoBDD\no_catalogos.xml', SINGLE_BLOB) AS X;

        -- extracción e inserción de datos en la tabla temporal de personas
        INSERT INTO @Persona (
            IdTipoDoc, ValorDocumentoIdentidad, Nombre, 
            FechaNacimiento, Email, telefono1, telefono2
        )
        SELECT T.Nodo.value('@TipoDocuIdentidad', 'INT'),
               T.Nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(32)'),
               T.Nodo.value('@Nombre', 'VARCHAR(64)'),
               T.Nodo.value('@FechaNacimiento', 'DATE'),
               T.Nodo.value('@Email', 'VARCHAR(64)'),
               T.Nodo.value('@telefono1', 'VARCHAR(64)'),
               T.Nodo.value('@telefono2', 'VARCHAR(64)')
        FROM @datos.nodes('//Personas/Persona') AS T(Nodo);

        -- extracción e inserción de datos en la tabla temporal de usuarios
        INSERT INTO @Usuario (Username, Pass, EsAdministrador, ValorDocumento)
        SELECT T.Nodo.value('@User', 'VARCHAR(64)'),
               T.Nodo.value('@Pass', 'VARCHAR(64)'),
               T.Nodo.value('@EsAdministrador', 'BIT'),
               T.Nodo.value('@ValorDocId', 'VARCHAR(32)')
        FROM @datos.nodes('//Usuarios/Usuario') AS T(Nodo);

        -- extracción e inserción de datos en la tabla temporal de cuentas
        INSERT INTO @Cuenta (NumeroCuenta, ValorDocumento, IdTipoCuenta, FechaCreacion, Saldo)
        SELECT T.Nodo.value('@NumeroCuenta', 'VARCHAR(20)'),
               T.Nodo.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(32)'),
               T.Nodo.value('@TipoCuentaId', 'INT'),
               T.Nodo.value('@FechaCreacion', 'DATE'),
               T.Nodo.value('@Saldo', 'DECIMAL(18,2)')
        FROM @datos.nodes('//Cuentas/Cuenta') AS T(Nodo);

        -- extracción e inserción de datos en la tabla temporal de beneficiarios
        INSERT INTO @Beneficiario (NumeroCuenta, ValorDocumento, IdParentesco, Porcentaje)
        SELECT T.Nodo.value('@NumeroCuenta', 'VARCHAR(20)'),
               T.Nodo.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(32)'),
               T.Nodo.value('@IdParentezco', 'INT'),
               T.Nodo.value('@Porcentaje', 'INT')
        FROM @datos.nodes('//Beneficiarios/Beneficiario') AS T(Nodo);

        -- extracción e inserción de datos en la tabla temporal de estados de cuenta
        INSERT INTO @EstadoCuenta (
            NumeroCuenta, fechaInicio, fechafin, saldoinicial, 
            saldoMinimo, saldo_final, interesesAcumulados, 
            cantRetiros, cantDepositos, cantSinpeEntrantes, cantSinpeSalientes
        )
        SELECT T.Nodo.value('@NumeroCuenta', 'VARCHAR(20)'),
               T.Nodo.value('@fechaInicio', 'DATE'),
               T.Nodo.value('@fechafin', 'DATE'),
               T.Nodo.value('@saldoinicial', 'DECIMAL(18,2)'),
               T.Nodo.value('@saldoMinimo', 'DECIMAL(18,2)'),
               T.Nodo.value('@saldo_final', 'DECIMAL(18,2)'),
               T.Nodo.value('@interesesAcumulados', 'DECIMAL(18,2)'),
               T.Nodo.value('@cantRetiros', 'INT'),
               T.Nodo.value('@cantDepositos', 'INT'),
               T.Nodo.value('@cantSinpeEntrantes', 'INT'),
               T.Nodo.value('@cantSinpeSalientes', 'INT')
        FROM @datos.nodes('//Estados_de_Cuenta/Estado_de_Cuenta') AS T(Nodo);

        -- extracción e inserción de datos en la tabla temporal de permisos de visualización
        INSERT INTO @UsuarioPuedeVer (Username, NumeroCuenta)
        SELECT T.Nodo.value('@User', 'VARCHAR(64)'),
               T.Nodo.value('@NumeroCuenta', 'VARCHAR(20)')
        FROM @datos.nodes('//Usuarios_Ver/UsuarioPuedeVer') AS T(Nodo);

        -- mapeo mediante inner joins por id
        BEGIN TRANSACTION tCargarNoCatalogos;

            -- insertar en la tabla  de personas
            INSERT INTO dbo.Persona (
                IdTipoDoc, ValorDocumentoIdentidad, Nombre, 
                FechaNacimiento, Email, telefono1, telefono2
            )
            SELECT XP.IdTipoDoc, XP.ValorDocumentoIdentidad, XP.Nombre, 
                   XP.FechaNacimiento, XP.Email, XP.telefono1, XP.telefono2
            FROM @Persona AS XP;

            -- insertar en usuarios mapeando la cédula al id numérico de persona
            INSERT INTO dbo.Usuario (Username, Pass, EsAdministrador, IdPersona)
            SELECT XU.Username, XU.Pass, XU.EsAdministrador, P.Id
            FROM @Usuario AS XU
            INNER JOIN dbo.Persona AS P 
                ON P.ValorDocumentoIdentidad = XU.ValorDocumento;

            -- insertar en cuentas mapeando el cliente al id numérico de persona
            INSERT INTO dbo.Cuenta (IdTipoCuenta, NumeroCuenta, FechaCreacion, Saldo, IdPersona)
            SELECT XC.IdTipoCuenta, XC.NumeroCuenta, XC.FechaCreacion, XC.Saldo, P.Id
            FROM @Cuenta AS XC
            INNER JOIN dbo.Persona AS P 
                ON P.ValorDocumentoIdentidad = XC.ValorDocumento;

            -- insertar beneficiarios realizando el mapeo hacia cuentas y personas por ids
            INSERT INTO dbo.Beneficiario (
                IdParentesco, Porcentaje, Activo, 
                FechaDesactivacion, IdCuenta, IdPersonaBeneficiario
            )
            SELECT XB.IdParentesco, XB.Porcentaje, 1, NULL, C.Id, P.Id
            FROM @Beneficiario AS XB
            INNER JOIN dbo.Cuenta AS C 
                ON C.NumeroCuenta = XB.NumeroCuenta
            INNER JOIN dbo.Persona AS P 
                ON P.ValorDocumentoIdentidad = XB.ValorDocumento;

            -- insertar estados de cuenta mapeando el número de cuenta al id numérico correspondiente
            INSERT INTO dbo.Estado_Cuenta (
                IdCuenta, fechaInicio, fechafin, saldoinicial, 
                saldoMinimo, saldo_final, interesesAcumulados, 
                cantRetiros, cantDepositos, cantSinpeEntrantes, cantSinpeSalientes
            )
            SELECT C.Id, XE.fechaInicio, XE.fechafin, XE.saldoinicial, 
                   XE.saldoMinimo, XE.saldo_final, XE.interesesAcumulados, 
                   XE.cantRetiros, XE.cantDepositos, XE.cantSinpeEntrantes, XE.cantSinpeSalientes
            FROM @EstadoCuenta AS XE
            INNER JOIN dbo.Cuenta AS C 
                ON C.NumeroCuenta = XE.NumeroCuenta;

            -- insertar tabla de permisos mapeando el nombre de usuario y cuenta a sus respectivos ids
            INSERT INTO dbo.Usuarios_Ver (IdUsuario, IdCuenta)
            SELECT U.Id, C.Id
            FROM @UsuarioPuedeVer AS XV
            INNER JOIN dbo.Usuario AS U 
                ON U.Username = XV.Username
            INNER JOIN dbo.Cuenta AS C 
                ON C.NumeroCuenta = XV.NumeroCuenta;

        COMMIT TRANSACTION tCargarNoCatalogos;

    END TRY
    BEGIN CATCH
        -- si ocurre algún fallo se revierte
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outResultCode = 50000; -- código de error
    END CATCH;

    SET NOCOUNT OFF;
END;
GO