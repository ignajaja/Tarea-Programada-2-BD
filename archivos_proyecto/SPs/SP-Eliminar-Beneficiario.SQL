CREATE OR ALTER PROCEDURE dbo.sp_EliminarBeneficiario
    @in_Username VARCHAR(64),
    @in_BeneficiarioId INT,
<<<<<<< Updated upstream
    @in_IP VARCHAR(64) = '0.0.0.0'
    
=======
    @out_Codigo INT OUTPUT,
    @out_Mensaje VARCHAR(256) OUTPUT,
	@in_IP VARCHAR(64) = '0.0.0.0'
>>>>>>> Stashed changes
AS
BEGIN
    SET NOCOUNT ON;

    -- 0 exito, 1 otros errores, 2 el beneficiario ya estaba desactivado,
    -- 3 el beneficiario no existe o no pertenece a una cuenta del usuario
    DECLARE @out_Codigo INT = 1;
    DECLARE @out_Mensaje VARCHAR(256) ='';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el usuario existe y pertenece a una cuenta
        IF NOT EXISTS (
            SELECT 1
            FROM Beneficiario
            INNER JOIN Usuarios_Ver ON Beneficiario.NumeroCuenta = Usuarios_Ver.NumeroCuenta
            WHERE Beneficiario.Id = @in_BeneficiarioId
                AND Usuarios_Ver.Username = @in_Username
        )
        BEGIN
            SET @out_Codigo = 3;
            SET @out_Mensaje = 'El beneficiario no existe, o no pertenece a una de sus cuentas';
            ROLLBACK TRANSACTION;
            SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
            RETURN;
        END

        -- Validar que el usuario está activo
        IF NOT EXISTS (SELECT 1 FROM Beneficiario WHERE Id = @in_BeneficiarioId AND Activo = 1)
        BEGIN
            SET @out_Codigo = 2;
            SET @out_Mensaje = 'El beneficiario no existe, o no pertenece a una de sus cuentas';
            ROLLBACK TRANSACTION;
            SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje;
            RETURN;
        END

        --- Se guarda el json antes de realizar el cambio
        DECLARE @jsonAntes VARCHAR(MAX);
		SET @jsonAntes = (
			SELECT 
				Beneficiario.Id, 
				Beneficiario.Activo, 
				Beneficiario.FechaDesactivacion 
			FROM Beneficiario 
			WHERE Beneficiario.Id = @in_BeneficiarioId
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		);


        --Se cambia el estado de activo a inactivo y almacena fecha
        UPDATE Beneficiario 
        SET Activo = 0, FechaDesactivacion = GETDATE() 
        WHERE Id = @in_BeneficiarioId AND Activo =1;

        -- Se guarda el json luego de realizar el cambio
        DECLARE @jsonDespues VARCHAR(MAX);
		SET @jsonDespues = (
			SELECT 
				Beneficiario.Id, 
				Beneficiario.Activo, 
				Beneficiario.FechaDesactivacion 
			FROM Beneficiario 
			WHERE Beneficiario.Id = @in_BeneficiarioId
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		);

        --En la bitacora se registra con operacion 5 que corresponde a eliminar beneficiario
        EXEC dbo.sp_RegistrarBitacora @in_Username = @in_Username, @in_IdTipoOperacion = 5, @in_JsonAntes = @jsonAntes, @in_JsonDespues = @jsonDespues, @in_IP = @in_IP;

        COMMIT TRANSACTION;
        SET @out_Codigo = 0;
        SET @out_Mensaje = 'El beneficiario se ha desligado de su cuenta exitosamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @out_Codigo = 1;
        SET @out_Mensaje = ERROR_MESSAGE();
    END CATCH

    SELECT @out_Codigo AS Codigo, @out_Mensaje AS Mensaje
END;