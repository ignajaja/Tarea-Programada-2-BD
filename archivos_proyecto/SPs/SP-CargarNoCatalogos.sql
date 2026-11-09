CREATE OR ALTER PROCEDURE [dbo].[sp_CargarCatalogos]
    @outResultCode INT OUTPUT -- código de resultado de la operación (0 éxito, otro error)
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    BEGIN TRY
        DECLARE @datos XML;        -- variable para almacenar el contenido del archivo xml
        SET @outResultCode = 0;      -- inicializar código de éxito por defecto

        -- Leer el archivo xml de catálogos mediante openrowset (Verifica que la ruta y nombre del XML sean correctos)
        SELECT @datos = X.BulkColumn
        FROM OPENROWSET(BULK 'C:\archivoBDD\CatalogosTarea3.xml', SINGLE_BLOB) AS X;

        -- Bloque transaccional para asegurar la atomicidad de las inserciones
        BEGIN TRANSACTION tCargarCatalogos;

            -- 1. Insertar tipos de documento de identidad
            INSERT INTO dbo.Tipo_Doc (Id, Nombre)
            SELECT T.Nodo.value('@Id', 'INT'),
                   T.Nodo.value('@Nombre', 'VARCHAR(100)')
            FROM @datos.nodes('/Catalogos/Tipo_Doc/TipoDocuIdentidad') AS T(Nodo)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.Tipo_Doc WHERE Id = T.Nodo.value('@Id', 'INT')
            );

            -- 2. Insertar tipos de moneda
            INSERT INTO dbo.Tipo_Moneda (Id, Nombre, Simbolo)
            SELECT T.Nodo.value('@Id', 'INT'),
                   T.Nodo.value('@Nombre', 'VARCHAR(50)'),
                   T.Nodo.value('@Simbolo', 'NVARCHAR(5)')
            FROM @datos.nodes('/Catalogos/Tipo_Moneda/TipoMoneda') AS T(Nodo)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.Tipo_Moneda WHERE Id = T.Nodo.value('@Id', 'INT')
            );

            -- 3. Insertar los parentezcos
            INSERT INTO dbo.Parentesco (Id, Nombre)
            SELECT T.Nodo.value('@Id', 'INT'),
                   T.Nodo.value('@Nombre', 'VARCHAR(50)')
            FROM @datos.nodes('/Catalogos/Parentezcos/Parentezco') AS T(Nodo)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.Parentesco WHERE Id = T.Nodo.value('@Id', 'INT')
            );

            -- 4. Insertar los tipos de cuenta de ahorro (Con atributos actualizados de Tarea 3: SINPE y cargos)[cite: 19, 23]
            INSERT INTO dbo.Tipo_Cuenta_Ahorros (
                Id, Nombre, IdTipoMoneda, SaldoMinimo, MultaSaldoMin, CargoMensual, 
                NumRetirosHumano, NumRetirosAutomatico, ComisionHumano, ComisionAutomatico, 
                MontoMaxSinpeDiario, ComisionSinpe, TasaInteresAnual
            )
            SELECT T.Nodo.value('@Id', 'INT'),
                   T.Nodo.value('@Nombre', 'VARCHAR(100)'),
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
                   T.Nodo.value('@TasaInteresAnual', 'DECIMAL(18,2)')
            FROM @datos.nodes('/Catalogos/Tipo_Cuenta_Ahorros/TipoCuentaAhorro') AS T(Nodo)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.Tipo_Cuenta_Ahorros WHERE Id = T.Nodo.value('@Id', 'INT')
            );

            -- 5. Insertar los tipos de movimiento (NUEVO Tarea 3)[cite: 19, 23]
            INSERT INTO dbo.Tipos_Movimiento (Id, Nombre, Accion, flagGeneraComprobante)
            SELECT T.Nodo.value('@Id', 'INT'),
                   T.Nodo.value('@Nombre', 'VARCHAR(100)'),
                   T.Nodo.value('@Accion', 'VARCHAR(10)'),
                   T.Nodo.value('@flagGeneraComprobante', 'BIT')
            FROM @datos.nodes('/Catalogos/Tipos_Movimiento/TipoMovimiento') AS T(Nodo)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.Tipos_Movimiento WHERE Id = T.Nodo.value('@Id', 'INT')
            );

            -- 6. Insertar los tipos de operación para la bitácora
            INSERT INTO dbo.TipoOperacion (Id, Nombre)
            SELECT T.Nodo.value('@Id', 'INT'),
                   T.Nodo.value('@Nombre', 'VARCHAR(100)')
            FROM @datos.nodes('/Catalogos/TipoOperacionesBitacora/TipoOperacion') AS T(Nodo)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.TipoOperacion WHERE Id = T.Nodo.value('@Id', 'INT')
            );

        COMMIT TRANSACTION tCargarCatalogos;

    END TRY
    BEGIN CATCH
        -- Si ocurre algún fallo se revierte toda la transacción
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outResultCode = 50000; -- código de error
    END CATCH;

    SET NOCOUNT OFF;
END;
GO