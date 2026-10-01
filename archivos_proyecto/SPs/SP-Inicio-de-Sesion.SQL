CREATE PROCEDURE dbo.sp_IniciarSesion
    @in_Username VARCHAR(50),
    @in_Pass VARCHAR(100),
    @out_EsAdministrador BIT OUTPUT,
    @out_CodigoRespuesta INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	
	BEGIN TRY
		
		BEGIN TRANSACTION; --Se inicia la transacción de iniciar sesión para garantizar atomicidad
		
		IF EXISTS (SELECT 1 FROM Usuarios WHERE Username = @in_Username AND Pass = @in_Pass)
		BEGIN --Si existe el usuario que se ingresó
			SELECT @out_EsAdministrador = EsAdministrador 
            FROM Usuarios 
            WHERE Username = @in_Username AND Pass = @in_Pass;
			SET @out_CodigoRespuesta = 0; --Código 0 para éxito al iniciar sesión
		END
		ELSE
		BEGIN --Si no existen se setean valores por defecto para las variables, código 1 para error
			SET @out_EsAdministrador = 0;
            SET @out_CodigoRespuesta = 1;
		END
		
		COMMIT TRANSACTION; --Finaliza la transacción
		
	END TRY
		
	BEGIN CATCH
		IF @@TRANCOUNT > 0 --Si no se concretó la transacción se hace ROLLBACK
		BEGIN
			ROLLBACK TRANSACTION;
		END
		
		SET @out_CodigoRespuesta = ERROR_NUMBER(); --Se retorna el código de error que arroje el servidor
		SET @out_EsAdministrador = 0; --Valor por defecto para la variable esAdmin
		
	END CATCH
END;