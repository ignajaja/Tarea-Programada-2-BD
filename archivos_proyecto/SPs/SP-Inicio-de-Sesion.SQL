CREATE OR ALTER PROCEDURE dbo.sp_IniciarSesion
    @in_Username VARCHAR(64),
    @in_Pass VARCHAR(128),
    @out_EsAdministrador BIT OUTPUT,
    @out_CodigoRespuesta INT OUTPUT --0 para exito y 1 para error en credenciales
AS
BEGIN
	SET NOCOUNT ON;
	
	BEGIN TRY
		BEGIN TRANSACTION; 
		
		IF EXISTS (SELECT 1 FROM Usuarios WHERE Username = @in_Username AND Pass = @in_Pass) --Revisar que el usuario exista
		BEGIN 
			SELECT @out_EsAdministrador = EsAdministrador  --Consulta valor de si es admnistrador o no
            FROM Usuarios 
            WHERE Username = @in_Username AND Pass = @in_Pass;
			
			SET @out_CodigoRespuesta = 0; --Si existe, corigo de exito al iniciar sesion

            -- Se registra en bitacora el login, tipo operacion 1 corresponde a inicio de sesion
            EXEC dbo.sp_RegistrarBitacora 
                @in_Username = @in_Username, 
                @in_IdTipoOperacion = 1, 
                @in_JsonAntes = NULL, 
                @in_JsonDespues = NULL;
		END
		ELSE
		BEGIN 
			SET @out_EsAdministrador = 0; 
            SET @out_CodigoRespuesta = 1; --Credenciales invalidas
		END
		
		COMMIT TRANSACTION; 
		
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 
		BEGIN
			ROLLBACK TRANSACTION;
		END
		
		SET @out_CodigoRespuesta = ERROR_NUMBER(); 
		SET @out_EsAdministrador = 0; 
	END CATCH
END;