-- ============================================================
-- Crear tabla: niveles
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'niveles')
BEGIN
    CREATE TABLE [dbo].[niveles](
        [id] [bigint] IDENTITY(1,1) NOT NULL,
        [nombre] [nvarchar](50) NOT NULL,
        [created_at] [datetime] NULL,
        [updated_at] [datetime] NULL,
    PRIMARY KEY CLUSTERED 
    (
        [id] ASC
    ) WITH (
        PAD_INDEX = OFF, 
        STATISTICS_NORECOMPUTE = OFF, 
        IGNORE_DUP_KEY = OFF, 
        ALLOW_ROW_LOCKS = ON, 
        ALLOW_PAGE_LOCKS = ON
    ) ON [PRIMARY]
    ) ON [PRIMARY]
    
    PRINT 'Tabla niveles creada exitosamente'
END
ELSE
BEGIN
    PRINT 'Tabla niveles ya existe'
END
GO

-- ============================================================
-- Crear tabla: alumnos
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'alumnos')
BEGIN
    CREATE TABLE [dbo].[alumnos](
        [id] [bigint] IDENTITY(1,1) NOT NULL,
        [matricula] [nvarchar](10) NOT NULL,
        [nombre] [nvarchar](120) NOT NULL,
        [fecha_nacimiento] [date] NOT NULL,
        [telefono] [nvarchar](20) NOT NULL,
        [email] [nvarchar](50) NULL,
        [nivel_id] [bigint] NOT NULL,
        [created_at] [datetime] NULL,
        [updated_at] [datetime] NULL,
    PRIMARY KEY CLUSTERED 
    (
        [id] ASC
    ) WITH (
        PAD_INDEX = OFF, 
        STATISTICS_NORECOMPUTE = OFF, 
        IGNORE_DUP_KEY = OFF, 
        ALLOW_ROW_LOCKS = ON, 
        ALLOW_PAGE_LOCKS = ON
    ) ON [PRIMARY]
    ) ON [PRIMARY]
    
    PRINT 'Tabla alumnos creada exitosamente'
END
ELSE
BEGIN
    PRINT 'Tabla alumnos ya existe'
END
GO

-- ============================================================
-- Crear tabla: migrations
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'migrations')
BEGIN
    CREATE TABLE [dbo].[migrations](
        [id] [int] IDENTITY(1,1) NOT NULL,
        [migration] [nvarchar](255) NOT NULL,
        [batch] [int] NOT NULL,
    PRIMARY KEY CLUSTERED 
    (
        [id] ASC
    ) WITH (
        PAD_INDEX = OFF, 
        STATISTICS_NORECOMPUTE = OFF, 
        IGNORE_DUP_KEY = OFF, 
        ALLOW_ROW_LOCKS = ON, 
        ALLOW_PAGE_LOCKS = ON
    ) ON [PRIMARY]
    ) ON [PRIMARY]
    
    PRINT 'Tabla migrations creada exitosamente'
END
ELSE
BEGIN
    PRINT 'Tabla migrations ya existe'
END
GO

-- ============================================================
-- Crear tabla: sessions
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'sessions')
BEGIN
    CREATE TABLE [dbo].[sessions](
        [id] [nvarchar](255) NOT NULL,
        [user_id] [bigint] NULL,
        [ip_address] [nvarchar](45) NULL,
        [user_agent] [nvarchar](max) NULL,
        [payload] [nvarchar](max) NOT NULL,
        [last_activity] [int] NOT NULL,
    CONSTRAINT [sessions_id_primary] PRIMARY KEY CLUSTERED 
    (
        [id] ASC
    ) WITH (
        PAD_INDEX = OFF, 
        STATISTICS_NORECOMPUTE = OFF, 
        IGNORE_DUP_KEY = OFF, 
        ALLOW_ROW_LOCKS = ON, 
        ALLOW_PAGE_LOCKS = ON
    ) ON [PRIMARY]
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
    
    PRINT 'Tabla sessions creada exitosamente'
END
ELSE
BEGIN
    PRINT 'Tabla sessions ya existe'
END
GO

-- ============================================================
-- Crear Foreign Keys
-- ============================================================
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys 
    WHERE name = 'alumnos_nivel_id_foreign' 
    AND parent_object_id = OBJECT_ID('alumnos')
)
BEGIN
    ALTER TABLE [dbo].[alumnos]  
    WITH CHECK ADD CONSTRAINT [alumnos_nivel_id_foreign] 
    FOREIGN KEY([nivel_id])
    REFERENCES [dbo].[niveles] ([id])
    
    ALTER TABLE [dbo].[alumnos] 
    CHECK CONSTRAINT [alumnos_nivel_id_foreign]
    
    PRINT 'Foreign key alumnos_nivel_id_foreign creada exitosamente'
END
ELSE
BEGIN
    PRINT 'Foreign key alumnos_nivel_id_foreign ya existe'
END
GO

-- ============================================================
-- Registrar migración
-- ============================================================
IF NOT EXISTS (SELECT * FROM [dbo].[migrations] WHERE migration = '2024_01_create_tables')
BEGIN
    INSERT INTO [dbo].[migrations] (migration, batch)
    VALUES ('2024_01_create_tables', 1)
    PRINT 'Migración registrada'
END
GO

PRINT '✅ Script de migración completado exitosamente'
