CREATE OR ALTER PROCEDURE dbo.sp_LimpiarBaseDatos
    @out_ResultCode INT OUTPUT -- 0 exito, 50000 error de bd
AS
/*
ejemplo de ejecucion:
    DECLARE @resultado INT
    EXEC dbo.sp_LimpiarBaseDatos
        @out_ResultCode = @resultado OUTPUT
    SELECT @resultado AS ResultCode
*/
BEGIN
    -- desactivar el conteo de filas afectadas para optimizar el rendimiento
    SET NOCOUNT ON

    -- inicia en exito
    SET @out_ResultCode = 0

    BEGIN TRY
        -- se borran los registros
        DELETE FROM dbo.Simulacion_Log 
        DELETE FROM dbo.Simulacion_Control
        DELETE FROM dbo.Usuarios_Ver
        DELETE FROM dbo.Movimiento
        DELETE FROM dbo.Estado_Cuenta
        DELETE FROM dbo.Beneficiario
        DELETE FROM dbo.Usuario
        DELETE FROM dbo.Cuenta
        DELETE FROM dbo.Persona
        DELETE FROM dbo.TipoOperacion
        DELETE FROM dbo.Tipos_Movimiento
        DELETE FROM dbo.Tipo_Cuenta_Ahorros
        DELETE FROM dbo.Parentesco
        DELETE FROM dbo.Tipo_Moneda
        DELETE FROM dbo.Tipo_Doc
    END TRY
    BEGIN CATCH
        SET @out_ResultCode = 50000
    END CATCH
END
GO