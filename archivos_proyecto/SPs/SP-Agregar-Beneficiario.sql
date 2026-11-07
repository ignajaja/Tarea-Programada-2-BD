CREATE OR ALTER PROCEDURE dbo.sp_AgregarBeneficiario
    @in_Username VARCHAR(64),          -- usuario que realiza la acción
    @in_IdCuenta INT,                  -- id de la cuenta a la que se asocia el beneficiario
    @in_TipoDoc INT,                   -- id del tipo de documento de identidad
    @in_NombrePersona VARCHAR(64),     -- nombre completo de la persona beneficiaria
    @in_ValorDoc VARCHAR(32),          -- número o valor del documento de identidad
    @in_FechaNac DATE,                 -- fecha de nacimiento del beneficiario
    @in_Email VARCHAR(256),            -- correo electrónico de contacto
    @in_Tel1 VARCHAR(16),              -- primer teléfono de contacto
    @in_Tel2 VARCHAR(16),              -- segundo teléfono
    @in_IdParentesco INT,              -- id del parentesco con el dueño de la cuenta
    @in_Porcentaje INT,                -- porcentaje asignado de la herencia o cuenta
    @out_Codigo INT OUTPUT,            -- código de resultado de la operación (0 éxito, otro error)
    @out_Mensaje VARCHAR(256) OUTPUT,  -- mensaje del resultado
    @in_IP VARCHAR(64) = '0.0.0.0'     -- ip por defecto si no se recibe desde views.py
AS
BEGIN
    SET NOCOUNT ON; -- evitar mensajes sobre filas afectadas

    -- inicializar variables de salida con éxito por defecto
    SET @out_Codigo = 0;
    SET @out_Mensaje = 'Beneficiario agregado exitosamente.';

    -- obtener el id del usuario actual
    DECLARE @IdUsuario INT;            -- id numérico del usuario
    SELECT @IdUsuario = Id 
    FROM Usuario 
    WHERE Username = @in_Username;

    -- verificar que la cuenta pertenezca al usuario
    IF NOT EXISTS (
        SELECT 1 
        FROM Usuarios_Ver 
        WHERE IdUsuario = @IdUsuario 
          AND IdCuenta = @in_IdCuenta
    )
    BEGIN
        SET @out_Codigo = 3;
        SET @out_Mensaje = 'La cuenta indicada no pertenece al usuario.';
        SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
        RETURN;
    END

    -- verificar límite de beneficiarios activos (<= 3)
    IF (
        SELECT COUNT(*) 
        FROM Beneficiario 
        WHERE IdCuenta = @in_IdCuenta 
          AND Activo = 1
    ) >= 3
    BEGIN
        SET @out_Codigo = 1;
        SET @out_Mensaje = 'La cuenta ya alcanzó el límite de beneficiarios.';
        SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
        RETURN;
    END

    -- verificar si la persona beneficiaria ya existe en el sistema
    DECLARE @IdPersonaBeneficiario INT; -- id de la persona en la tabla maestra
    SELECT @IdPersonaBeneficiario = Id 
    FROM Persona 
    WHERE ValorDocumentoIdentidad = @in_ValorDoc;

    -- si la persona no existe, se inserta previamente
    IF @IdPersonaBeneficiario IS NULL
    BEGIN
        INSERT INTO Persona (
            IdTipoDoc, Nombre, ValorDocumentoIdentidad, 
            FechaNacimiento, Email, telefono1, telefono2
        )
        VALUES (
            @in_TipoDoc, @in_NombrePersona, @in_ValorDoc, 
            @in_FechaNac, @in_Email, @in_Tel1, @in_Tel2
        );
        SET @IdPersonaBeneficiario = SCOPE_IDENTITY();
    END

    -- verificar si la persona ya es beneficiaria activa de la cuenta
    IF EXISTS (
        SELECT 1 
        FROM Beneficiario 
        WHERE IdCuenta = @in_IdCuenta 
          AND IdPersonaBeneficiario = @IdPersonaBeneficiario 
          AND Activo = 1
    )
    BEGIN
        SET @out_Codigo = 4;
        SET @out_Mensaje = 'Esta persona ya es beneficiaria activa de la cuenta.';
        SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
        RETURN;
    END

    -- transaccion de inserción
    BEGIN TRY
        BEGIN TRANSACTION;

            -- insertar el nuevo beneficiario vinculado a la cuenta y persona
            INSERT INTO Beneficiario (
                IdCuenta, IdPersonaBeneficiario, 
                IdParentesco, Porcentaje, Activo
            )
            VALUES (
                @in_IdCuenta, @IdPersonaBeneficiario, 
                @in_IdParentesco, @in_Porcentaje, 1
            );

            -- generar el json con los datos del nuevo beneficiario
            DECLARE @jsonNuevo VARCHAR(MAX); -- almacena la estructura en formato json
            SET @jsonNuevo = (
                SELECT Nombre, ValorDocumentoIdentidad AS Documento, @in_Porcentaje AS Porcentaje
                FROM Persona 
                WHERE Id = @IdPersonaBeneficiario
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

            -- registrar la acción en la bitácora (tipo de operación 3)
            INSERT INTO Bitacora (IdUsuario, IdTipoOperacion, JsonDespues, IP, FechaHora)
            VALUES (@IdUsuario, 3, @jsonNuevo, @in_IP, GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- si ocurre un error deshace la transacción y retorna el error
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @out_Codigo = 2;
        SET @out_Mensaje = ERROR_MESSAGE();
    END CATCH

    -- retornar el código y mensaje final
    SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
END;
GO