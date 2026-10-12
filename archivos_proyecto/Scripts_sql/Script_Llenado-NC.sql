DECLARE @datos XML;

SELECT @datos = BulkColumn
FROM OPENROWSET(BULK 'C:\archivoBDD\no-catalogos.xml', SINGLE_BLOB) AS x;

-- --- INSERTS FOR: Personas ---
INSERT INTO Persona(
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
INSERT INTO Cuenta(
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
INSERT INTO Beneficiario(
    NumeroCuenta,
    ValorDocumentoIdentidadBeneficiario,
    ParentezcoId,
    Porcentaje,
    Activo
)
SELECT 
    node.value('@NumeroCuenta', 'VARCHAR(8)') AS NumeroCuenta,
    node.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(9)') AS ValorDocumentoIdentidadBeneficiario,
    node.value('@IdParentezco', 'INT') AS ParentezcoId,
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
INSERT INTO Usuario(
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

