CREATE OR ALTER PROCEDURE dbo.sp_CargarCatalogos
    @outResultCode INT OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion:
    DECLARE @resultado INT
    EXEC dbo.sp_CargarCatalogos @outResultCode = @resultado OUTPUT
    SELECT @resultado AS ResultCode
*/
BEGIN
	-- desactivar conteo de filas 
    SET NOCOUNT ON;

    -- inicia en exito
    SET @outResultCode = 0;

    -- contenido del xml de catalogos
    DECLARE @datos XML;

    BEGIN TRY
        -- lee el archivo xml de catalogos
        SELECT @datos = CONVERT(XML, X.BulkColumn)
        FROM OPENROWSET(BULK 'C:\archivoBDD\CatalogosTarea3.xml', SINGLE_BLOB) AS X;

        -- todos los catalogos se cargan en una transaccion
        BEGIN TRANSACTION tCargarCatalogos;

        -- tipos de documento de identidad
        INSERT INTO dbo.Tipo_Doc (Id, Nombre)
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(50)')
        FROM @datos.nodes('/Catalogos/Tipo_Doc/TipoDocuIdentidad') AS T(Nodo)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Tipo_Doc AS D WHERE D.Id = T.Nodo.value('@Id', 'INT')
        );

        -- tipos de moneda
        INSERT INTO dbo.Tipo_Moneda (Id, Nombre, Simbolo)
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(50)'),
            T.Nodo.value('@Simbolo', 'NVARCHAR(50)')
        FROM @datos.nodes('/Catalogos/Tipo_Moneda/TipoMoneda') AS T(Nodo)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Tipo_Moneda AS M WHERE M.Id = T.Nodo.value('@Id', 'INT')
        );

        -- parentescos
        INSERT INTO dbo.Parentesco (Id, Nombre)
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(50)')
        FROM @datos.nodes('/Catalogos/Parentezcos/Parentezco') AS T(Nodo)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Parentesco AS P WHERE P.Id = T.Nodo.value('@Id', 'INT')
        );

        -- tipos de cuenta de ahorro, necesita que los tipos de moneda ya esten cargados
        INSERT INTO dbo.Tipo_Cuenta_Ahorros (
            Id, Nombre, IdTipoMoneda, SaldoMinimo, MultaSaldoMin, CargoMensual,
            NumRetirosHumano, NumRetirosAutomatico, comisionHumano, comisionAutomatico,
            MontoMaxSinpeDiario, ComisionSinpe, TasaInteresAnual
        )
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(50)'),
            T.Nodo.value('@IdTipoMoneda', 'INT'),
            T.Nodo.value('@SaldoMinimo', 'DECIMAL(18,2)'),
            T.Nodo.value('@MultaSaldoMin', 'DECIMAL(18,2)'),
            T.Nodo.value('@CargoMensual', 'DECIMAL(18,2)'),
            T.Nodo.value('@NumRetirosHumano', 'INT'),
            T.Nodo.value('@NumRetirosAutomatico', 'INT'),
            T.Nodo.value('@ComisionHumano', 'DECIMAL(18,2)'),
            T.Nodo.value('@ComisionAutomatico', 'DECIMAL(18,2)'),
            T.Nodo.value('@MontoMaxSinpeDiario', 'DECIMAL(18,2)'),
            T.Nodo.value('@ComisionSinpe', 'DECIMAL(18,2)'),
            T.Nodo.value('@TasaInteresAnual', 'DECIMAL(5,2)')
        FROM @datos.nodes('/Catalogos/Tipo_Cuenta_Ahorros/TipoCuentaAhorro') AS T(Nodo)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Tipo_Cuenta_Ahorros AS TC WHERE TC.Id = T.Nodo.value('@Id', 'INT')
        );

        -- tipos de movimiento, incluye la accion y si genera comprobante
        INSERT INTO dbo.Tipos_Movimiento (Id, Nombre, Accion, flagGeneraComprobante)
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(64)'),
            T.Nodo.value('@Accion', 'VARCHAR(16)'),
            T.Nodo.value('@flagGeneraComprobante', 'BIT')
        FROM @datos.nodes('/Catalogos/Tipos_Movimiento/TipoMovimiento') AS T(Nodo)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Tipos_Movimiento AS TM WHERE TM.Id = T.Nodo.value('@Id', 'INT')
        );

        -- tipos de operacion de la bitacora
        INSERT INTO dbo.TipoOperacion (Id, Nombre)
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(50)')
        FROM @datos.nodes('/Catalogos/TipoOperacionesBitacora/TipoOperacion') AS T(Nodo)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.TipoOperacion AS TO1 WHERE TO1.Id = T.Nodo.value('@Id', 'INT')
        );

        COMMIT TRANSACTION tCargarCatalogos;
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