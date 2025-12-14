-- ============================================================
-- Seeds - Datos Iniciales
-- ============================================================

-- ============================================================
-- Insertar niveles
-- ============================================================
PRINT 'Insertando niveles...'

-- Verificar si ya existen niveles
IF NOT EXISTS (SELECT * FROM [dbo].[niveles] WHERE nombre = 'Primaria')
BEGIN
    INSERT INTO [dbo].[niveles] (nombre, created_at, updated_at)
    VALUES ('Primaria', GETDATE(), GETDATE())
    PRINT '✅ Nivel Primaria insertado'
END
ELSE
BEGIN
    PRINT 'ℹ️  Nivel Primaria ya existe'
END

IF NOT EXISTS (SELECT * FROM [dbo].[niveles] WHERE nombre = 'Secundaria')
BEGIN
    INSERT INTO [dbo].[niveles] (nombre, created_at, updated_at)
    VALUES ('Secundaria', GETDATE(), GETDATE())
    PRINT '✅ Nivel Secundaria insertado'
END
ELSE
BEGIN
    PRINT 'ℹ️  Nivel Secundaria ya existe'
END

IF NOT EXISTS (SELECT * FROM [dbo].[niveles] WHERE nombre = 'Preparatoria')
BEGIN
    INSERT INTO [dbo].[niveles] (nombre, created_at, updated_at)
    VALUES ('Preparatoria', GETDATE(), GETDATE())
    PRINT '✅ Nivel Preparatoria insertado'
END
ELSE
BEGIN
    PRINT 'ℹ️  Nivel Preparatoria ya existe'
END
GO

-- ============================================================
-- Insertar alumnos de ejemplo
-- ============================================================
PRINT 'Insertando alumnos de ejemplo...'

DECLARE @nivel_primaria_id BIGINT
SELECT @nivel_primaria_id = id FROM [dbo].[niveles] WHERE nombre = 'Primaria'

-- Alumno 1: Luis Pérez
IF NOT EXISTS (SELECT * FROM [dbo].[alumnos] WHERE matricula = 'A001')
BEGIN
    INSERT INTO [dbo].[alumnos] 
    (matricula, nombre, fecha_nacimiento, telefono, email, nivel_id, created_at, updated_at)
    VALUES 
    ('A001', 'Luis Pérez', '2000-06-15', '987654321', 'luis.perez@example.com', @nivel_primaria_id, GETDATE(), GETDATE())
    PRINT '✅ Alumno Luis Pérez insertado'
END
ELSE
BEGIN
    PRINT 'ℹ️  Alumno Luis Pérez ya existe'
END

-- Alumno 2: María González
IF NOT EXISTS (SELECT * FROM [dbo].[alumnos] WHERE matricula = 'A002')
BEGIN
    INSERT INTO [dbo].[alumnos] 
    (matricula, nombre, fecha_nacimiento, telefono, email, nivel_id, created_at, updated_at)
    VALUES 
    ('A002', 'María González', '2001-03-20', '987654322', 'maria.gonzalez@example.com', @nivel_primaria_id, GETDATE(), GETDATE())
    PRINT '✅ Alumno María González insertado'
END
ELSE
BEGIN
    PRINT 'ℹ️  Alumno María González ya existe'
END

-- Alumno 3: Carlos Ramírez
IF NOT EXISTS (SELECT * FROM [dbo].[alumnos] WHERE matricula = 'A003')
BEGIN
    INSERT INTO [dbo].[alumnos] 
    (matricula, nombre, fecha_nacimiento, telefono, email, nivel_id, created_at, updated_at)
    VALUES 
    ('A003', 'Carlos Ramírez', '1999-11-10', '987654323', 'carlos.ramirez@example.com', @nivel_primaria_id, GETDATE(), GETDATE())
    PRINT '✅ Alumno Carlos Ramírez insertado'
END
ELSE
BEGIN
    PRINT 'ℹ️  Alumno Carlos Ramírez ya existe'
END
GO

-- ============================================================
-- Verificar datos insertados
-- ============================================================
PRINT ''
PRINT '📊 Resumen de datos:'
PRINT '===================='

DECLARE @total_niveles INT
DECLARE @total_alumnos INT

SELECT @total_niveles = COUNT(*) FROM [dbo].[niveles]
SELECT @total_alumnos = COUNT(*) FROM [dbo].[alumnos]

PRINT 'Total niveles: ' + CAST(@total_niveles AS NVARCHAR(10))
PRINT 'Total alumnos: ' + CAST(@total_alumnos AS NVARCHAR(10))

-- Mostrar niveles
PRINT ''
PRINT 'Niveles disponibles:'
SELECT id, nombre FROM [dbo].[niveles]

-- Mostrar alumnos
PRINT ''
PRINT 'Alumnos registrados:'
SELECT id, matricula, nombre, email FROM [dbo].[alumnos]

PRINT ''
PRINT '✅ Seeds ejecutados exitosamente'
