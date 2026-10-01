DECLARE @datos XML;

SELECT @datos = BulkColumn
FROM OPENROWSET(BULK 'C:\archivoBDD\catalogos.xml', SINGLE_BLOB) AS x;

-- --- INSERTS FOR: TipoDocuIdentidad ---
INSERT INTO Tipo_Doc(Id, Nombre)
SELECT 
    Node.value('@Id', 'INT') AS Id,
    Node.value('@Nombre', 'VARCHAR(100)') AS Nombre
FROM @datos.nodes('//Tipo_Doc/TipoDocuIdentidad') AS T(Node);


-- --- INSERTS FOR: TipoMoneda ---
INSERT INTO Tipo_Moneda (Id, Nombre, Simbolo)
SELECT 
    Node.value('@Id', 'INT') AS Id,
    Node.value('@Nombre', 'VARCHAR(50)') AS Nombre,
    Node.value('@Simbolo', 'NVARCHAR(5)') AS Simbolo
FROM @datos.nodes('//Tipo_Moneda/TipoMoneda') AS T(Node);


-- --- INSERTS FOR: Parentezco ---
INSERT INTO Parentezcos (Id, Nombre)
SELECT 
    Node.value('@Id', 'INT') AS Id,
    Node.value('@Nombre', 'VARCHAR(50)') AS Nombre
FROM @datos.nodes('//Parentezcos/Parentezco') AS T(Node);


-- --- INSERTS FOR: TipoCuentaAhorro ---
INSERT INTO Tipo_Cuenta_Ahorros (
    Id, Nombre, IdTipoMoneda, SaldoMinimo, MultaSaldoMin, CargoAnual, 
    NumRetirosHumano, NumRetirosAutomatico, ComisionHumano, ComisionAutomatico, Interes
)
SELECT 
    Node.value('@Id', 'INT'),
    Node.value('@Nombre', 'VARCHAR(100)'),
    Node.value('@IdTipoMoneda', 'INT'),
    Node.value('@SaldoMinimo', 'DECIMAL(18,2)'),
    Node.value('@MultaSaldoMin', 'DECIMAL(18,2)'),
    Node.value('@CargoAnual', 'DECIMAL(18,2)'),
    Node.value('@NumRetirosHumano', 'INT'),
    Node.value('@NumRetirosAutomatico', 'INT'),
    Node.value('@comisionHumano', 'DECIMAL(18,2)'),
    COALESCE(Node.value('@comisionAutomatico', 'DECIMAL(18,2)'), Node.value('@omisionAutomatico', 'DECIMAL(18,2)')),
    Node.value('@interes', 'INT')
FROM @datos.nodes('//Tipo_Cuenta_Ahorros/TipoCuentaAhorro') AS T(Node);


--Inserts Catalogo Tipos de operacion--
INSERT INTO TipoOperaciones (Id, Nombre)
SELECT 
    Node.value('@id', 'INT') AS Id,
    Node.value('@nombre', 'VARCHAR(100)') AS Nombre
FROM @datos.nodes('//TipoOperaciones/TipoOperacion') AS T(Node);


--Prueba final--
SELECT * FROM Tipo_Doc;
SELECT * FROM Tipo_Moneda;
SELECT * FROM Parentezcos;
SELECT * FROM Tipo_Cuenta_Ahorros;
SELECT * FROM TipoOperaciones;