DECLARE @datos XML;

SELECT @datos = BulkColumn
FROM OPENROWSET(BULK 'C:\archivoBDD\no-catalogos.xml', SINGLE_BLOB) AS x;

-- --- INSERTS FOR: Personas ---
INSERT INTO Personas(
    TipoDocuIdentidad,
    Nombre,
    ValorDocumentoIdentidad,
    FechaNacimiento,
    Email,
    telefono1,
    telefono2
)
SELECT 
    node.value('@TipoDocuIdentidad', 'INT') AS TipoDocuIdentidad,
    node.value('@Nombre', 'VARCHAR(50)') AS Nombre,
    node.value('@ValorDocumentoIdentidad', 'VARCHAR(9)') AS ValorDocumentoIdentidad,
    node.value('@FechaNacimiento', 'DATE') AS FechaNacimiento,
    node.value('@Email', 'VARCHAR(50)') AS Email,
    node.value('@telefono1', 'VARCHAR(8)') AS telefono1,
    node.value('@telefono2', 'VARCHAR(8)') AS telefono2
    
FROM @datos.nodes('//Personas/Persona') AS T(Node);


-- --- INSERTS FOR: Cuentas ---
INSERT INTO Cuentas(
    ValorDocumentoIdentidadDelCliente,
    TipoCuentaId,
    NumeroCuenta,
    FechaCreacion,
    Saldo
)
SELECT 
    node.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(9)') AS TipoDocuIdentidad,
    node.value('@TipoCuentaId', 'INT') AS TipoCuentaId,
    node.value('@NumeroCuenta', 'VARCHAR(8)') AS NumeroCuenta,
    node.value('@FechaCreacion', 'VARCHAR(10)') AS FechaCreacion,
    node.value('@Saldo', 'DECIMAL(18,2)') AS Saldo
    
FROM @datos.nodes('//Cuentas/Cuenta') AS T(Node);


-- --- INSERTS FOR: Beneficiarios ---
INSERT INTO Beneficiarios(
    NumeroCuenta,
    ValorDocumentoIdentidadBeneficiario,
    ParentezcoId,
    Porcentaje,
    Activo
)
SELECT 
    node.value('@NumeroCuenta', 'VARCHAR(8)') AS NumeroCuenta,
    node.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(9)') AS ValorDocumentoIdentidadBeneficiario,
    node.value('@ParentezcoId', 'INT') AS ParentezcoId,
    node.value('@Porcentaje', 'INT') AS Porcentaje,
    1
    
FROM @datos.nodes('//Beneficiarios/Beneficiario') AS T(Node);


-- --- INSERTS FOR: Estados_de_Cuenta ---

INSERT INTO Estado_Cuenta (NumeroCuenta,
    fechaInicio,
    fechafin,
    saldoinicial,
    saldoMinimo,
    saldo_final,
    interesesAcumulados,
    cantRetiros,
    cantDepositos,
    cantSinpeEntrantes,
    cantSinpeSalientes
    )

SELECT 
    Node.value('@NumeroCuenta', 'VARCHAR(20)'),
    Node.value('@fechaInicio', 'DATE'),
    Node.value('@fechafin', 'DATE'),
    Node.value('@saldoinicial', 'DECIMAL(18,2)'),
    Node.value('@saldoMinimo', 'DECIMAL(18,2)'),
    Node.value('@saldo_final', 'DECIMAL(18,2)'),
    Node.value('@interesesAcumulados', 'DECIMAL(18,2)'),
    Node.value('@cantRetiros', 'INT'),
    Node.value('@cantDepositos', 'INT'),
    Node.value('@cantSinpeEntrantes', 'INT'),
    Node.value('@cantSinpeSalientes', 'INT')
FROM @datos.nodes('//Estados_de_Cuenta/Estado_de_Cuenta') AS T(Node);

-- --- INSERTS FOR: Usuarios ---
INSERT INTO Usuarios(
    Username,
    Pass,
    EsAdministrador
)
SELECT 
    node.value('@User', 'VARCHAR(12)') AS Username,
    node.value('@Pass', 'VARCHAR(12)') AS Pass,
    node.value('@EsAdministrador', 'INT') AS EsAdministrador
    
FROM @datos.nodes('//Usuarios/Usuario') AS T(Node);


-- --- INSERTS FOR: Usuarios_Ver ---
INSERT INTO Usuarios_Ver(
    Username,
    NumeroCuenta
)
SELECT 
    node.value('@User', 'VARCHAR(12)') AS Username,
    node.value('@NumeroCuenta', 'VARCHAR(8)') AS NumeroCuenta
    
FROM @datos.nodes('//Usuarios_Ver/UsuarioPuedeVer') AS T(Node);




DECLARE @datos XML; 

SELECT @datos = BulkColumn
FROM OPENROWSET(BULK 'C:\Users\gabri\OneDrive\Escritorio\no_catalogos.xml', SINGLE_BLOB) AS x; 

-- 1. Inserts para la tabla Persona
INSERT INTO Persona (TipoDocuIdentidad, Nombre, ValorDocumentoIdentidad, FechaNacimiento, Email, telefono1, telefono2)
SELECT 
    Node.value('@TipoDocuIdentidad', 'INT'),
    Node.value('@Nombre', 'VARCHAR(100)'),
    Node.value('@ValorDocumentoIdentidad', 'VARCHAR(50)'),
    Node.value('@FechaNacimiento', 'DATE'),
    Node.value('@Email', 'VARCHAR(100)'),
    Node.value('@telefono1', 'VARCHAR(20)'),
    Node.value('@telefono2', 'VARCHAR(20)')
FROM @datos.nodes('//Personas/Persona') AS T(Node);

-- 2. Inserts para la tabla Cuenta
INSERT INTO Cuenta (ValorDocumentoIdentidadDelCliente, TipoCuentaId, NumeroCuenta, FechaCreacion, Saldo)
SELECT 
    Node.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(50)'),
    Node.value('@TipoCuentaId', 'INT'),
    Node.value('@NumeroCuenta', 'VARCHAR(20)'),
    Node.value('@FechaCreacion', 'DATE'),
    Node.value('@Saldo', 'DECIMAL(18,2)')
FROM @datos.nodes('//Cuentas/Cuenta') AS T(Node);

-- 3. Inserts para la tabla Beneficiario (Usando ParentezcoId)
INSERT INTO Beneficiario (NumeroCuenta, ValorDocumentoIdentidadBeneficiario, ParentezcoId, Porcentaje)
SELECT 
    Node.value('@NumeroCuenta', 'VARCHAR(20)'),
    Node.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(50)'),
    Node.value('@IdParentezco', 'INT'),
    Node.value('@Porcentaje', 'DECIMAL(5,2)')
FROM @datos.nodes('//Beneficiarios/Beneficiario') AS T(Node);

-- 4. Inserts para la tabla Estado_Cuenta
INSERT INTO Estado_Cuenta (NumeroCuenta, fechaInicio, fechafin, saldoinicial, saldoMinimo, saldo_final, interesesAcumulados, cantRetiros, cantDepositos, cantSinpeEntrantes, cantSinpeSalientes)
SELECT 
    Node.value('@NumeroCuenta', 'VARCHAR(20)'),
    Node.value('@fechaInicio', 'DATE'),
    Node.value('@fechafin', 'DATE'),
    Node.value('@saldoinicial', 'DECIMAL(18,2)'),
    Node.value('@saldoMinimo', 'DECIMAL(18,2)'),
    Node.value('@saldo_final', 'DECIMAL(18,2)'),
    Node.value('@interesesAcumulados', 'DECIMAL(18,2)'),
    Node.value('@cantRetiros', 'INT'),
    Node.value('@cantDepositos', 'INT'),
    Node.value('@cantSinpeEntrantes', 'INT'),
    Node.value('@cantSinpeSalientes', 'INT')
FROM @datos.nodes('//Estados_de_Cuenta/Estado_de_Cuenta') AS T(Node);

-- 5. Inserts para la tabla Usuario (Solo las columnas reales que tiene tu tabla)
INSERT INTO Usuario (Username, Pass, EsAdministrador)
SELECT 
    Node.value('@User', 'VARCHAR(50)'),
    Node.value('@Pass', 'VARCHAR(100)'),
    Node.value('@EsAdministrador', 'BIT')
FROM @datos.nodes('//Usuarios/Usuario') AS T(Node);

-- 6. Inserts para la tabla Usuarios_Ver