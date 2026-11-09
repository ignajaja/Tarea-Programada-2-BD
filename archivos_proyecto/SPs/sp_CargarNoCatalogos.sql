CREATE OR ALTER PROCEDURE dbo.sp_CargarNoCatalogos
    @outResultCode INT OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion:
    DECLARE @resultado INT
    EXEC dbo.sp_CargarNoCatalogos @outResultCode = @resultado OUTPUT
    SELECT @resultado AS ResultCode
*/
BEGIN
	--desactivar conteo de filas
    SET NOCOUNT ON;

    -- inicia en exito
    SET @outResultCode = 0;

    -- contenido del xml de datos no catalogos
    DECLARE @datos XML;

    -- tablas temporales donde se carga el xml antes de mapear a los ids reales
    DECLARE @Persona TABLE (
        IdTipoDoc INT,
        ValorDocumentoIdentidad VARCHAR(20),
        Nombre VARCHAR(100),
        FechaNacimiento DATE,
        Email VARCHAR(100),
        telefono1 VARCHAR(20),
        telefono2 VARCHAR(20)
    );
    DECLARE @Usuario TABLE (
        Username VARCHAR(50),
        Pass VARCHAR(100),
        EsAdministrador BIT,
        ValorDocumento VARCHAR(20) -- documento de la persona dueña del usuario
    );
    DECLARE @Cuenta TABLE (
        NumeroCuenta VARCHAR(20),
        ValorDocumento VARCHAR(20), -- documento del cliente dueño de la cuenta
        IdTipoCuenta INT,
        FechaCreacion DATE,
        Saldo DECIMAL(18,2)
    );
    DECLARE @Beneficiario TABLE (
        NumeroCuenta VARCHAR(20),
        ValorDocumento VARCHAR(20), -- documento de la persona beneficiaria
        IdParentesco INT,
        Porcentaje INT
    );
    DECLARE @UsuarioPuedeVer TABLE (
        Username VARCHAR(50),
        NumeroCuenta VARCHAR(20)
    );

    BEGIN TRY
        -- lee el archivo xml
        SELECT @datos = CONVERT(XML, X.BulkColumn)
        FROM OPENROWSET(BULK 'C:\archivoBDD\no_catalogos.xml', SINGLE_BLOB) AS X;

        -- carga personas
        INSERT INTO @Persona (IdTipoDoc, ValorDocumentoIdentidad, Nombre, FechaNacimiento, Email, telefono1, telefono2)
        SELECT
            T.Nodo.value('@TipoDocuIdentidad', 'INT'),
            T.Nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(20)'),
            T.Nodo.value('@Nombre', 'VARCHAR(100)'),
            T.Nodo.value('@FechaNacimiento', 'DATE'),
            T.Nodo.value('@Email', 'VARCHAR(100)'),
            T.Nodo.value('@telefono1', 'VARCHAR(20)'),
            T.Nodo.value('@telefono2', 'VARCHAR(20)')
        FROM @datos.nodes('//Personas/Persona') AS T(Nodo);

        -- carga usuarios
        INSERT INTO @Usuario (Username, Pass, EsAdministrador, ValorDocumento)
        SELECT
            T.Nodo.value('@User', 'VARCHAR(50)'),
            T.Nodo.value('@Pass', 'VARCHAR(100)'),
            T.Nodo.value('@EsAdministrador', 'BIT'),
            T.Nodo.value('@ValorDocId', 'VARCHAR(20)')
        FROM @datos.nodes('//Usuarios/Usuario') AS T(Nodo);

        -- carga cuentas
        INSERT INTO @Cuenta (NumeroCuenta, ValorDocumento, IdTipoCuenta, FechaCreacion, Saldo)
        SELECT
            T.Nodo.value('@NumeroCuenta', 'VARCHAR(20)'),
            T.Nodo.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(20)'),
            T.Nodo.value('@TipoCuentaId', 'INT'),
            T.Nodo.value('@FechaCreacion', 'DATE'),
            T.Nodo.value('@Saldo', 'DECIMAL(18,2)')
        FROM @datos.nodes('//Cuentas/Cuenta') AS T(Nodo);

        -- carga beneficiarios
        INSERT INTO @Beneficiario (NumeroCuenta, ValorDocumento, IdParentesco, Porcentaje)
        SELECT
            T.Nodo.value('@NumeroCuenta', 'VARCHAR(20)'),
            T.Nodo.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(20)'),
            T.Nodo.value('@IdParentezco', 'INT'),
            T.Nodo.value('@Porcentaje', 'INT')
        FROM @datos.nodes('//Beneficiarios/Beneficiario') AS T(Nodo);

        -- carga permisos de visualizacion
        INSERT INTO @UsuarioPuedeVer (Username, NumeroCuenta)
        SELECT
            T.Nodo.value('@User', 'VARCHAR(50)'),
            T.Nodo.value('@NumeroCuenta', 'VARCHAR(20)')
        FROM @datos.nodes('//Usuarios_Ver/UsuarioPuedeVer') AS T(Nodo);

        -- las inserciones definitivas se hacen en una transaccion
        BEGIN TRANSACTION tCargarNoCatalogos;

        -- inserta personas que aun no existen
        INSERT INTO dbo.Persona (IdTipoDoc, ValorDocumentoIdentidad, Nombre, FechaNacimiento, Email, telefono1, telefono2)
        SELECT X.IdTipoDoc, X.ValorDocumentoIdentidad, X.Nombre, X.FechaNacimiento, X.Email, X.telefono1, X.telefono2
        FROM @Persona AS X
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Persona AS P WHERE P.ValorDocumentoIdentidad = X.ValorDocumentoIdentidad
        );

        -- inserta usuarios mapeando el documento al id de la persona
        INSERT INTO dbo.Usuario (Username, Pass, EsAdministrador, IdPersona)
        SELECT X.Username, X.Pass, X.EsAdministrador, P.Id
        FROM @Usuario AS X
        INNER JOIN dbo.Persona AS P 
            ON P.ValorDocumentoIdentidad = X.ValorDocumento
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Usuario AS U WHERE U.Username = X.Username
        );

        -- inserta cuentas mapeando el documento del cliente al id de la persona
        INSERT INTO dbo.Cuenta (IdTipoCuenta, NumeroCuenta, FechaCreacion, Saldo, IdPersona)
        SELECT X.IdTipoCuenta, X.NumeroCuenta, X.FechaCreacion, X.Saldo, P.Id
        FROM @Cuenta AS X
        INNER JOIN dbo.Persona AS P 
            ON P.ValorDocumentoIdentidad = X.ValorDocumento
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Cuenta AS C WHERE C.NumeroCuenta = X.NumeroCuenta
        );

        -- inserta beneficiarios mapeando numero de cuenta y documento a sus ids
        INSERT INTO dbo.Beneficiario (IdParentesco, Porcentaje, Activo, FechaDesactivacion, IdCuenta, IdPersonaBeneficiario)
        SELECT X.IdParentesco, X.Porcentaje, 1, NULL, C.Id, P.Id
        FROM @Beneficiario AS X
        INNER JOIN dbo.Cuenta AS C 
            ON C.NumeroCuenta = X.NumeroCuenta
        INNER JOIN dbo.Persona AS P 
            ON P.ValorDocumentoIdentidad = X.ValorDocumento
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Beneficiario AS B WHERE B.IdCuenta = C.Id AND B.IdPersonaBeneficiario = P.Id
        );

        -- inserta permisos mapeando usuario y cuenta a sus ids
        INSERT INTO dbo.Usuarios_Ver (IdUsuario, IdCuenta)
        SELECT U.Id, C.Id
        FROM @UsuarioPuedeVer AS X
        INNER JOIN dbo.Usuario AS U 
            ON U.Username = X.Username
        INNER JOIN dbo.Cuenta AS C 
            ON C.NumeroCuenta = X.NumeroCuenta
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Usuarios_Ver AS UV WHERE UV.IdUsuario = U.Id AND UV.IdCuenta = C.Id
        );

        COMMIT TRANSACTION tCargarNoCatalogos;
    END TRY
    BEGIN CATCH
        -- ante cualquier error se deshace toda la carga
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;
        SET @outResultCode = 50000;
    END CATCH;
END;
GO