-- db/migrations/004_m03_security_roles.sql
-- Definición de Roles de Mínimo Privilegio para M03

-- 1. Rol Migrador (DDL sobre esquemas y tablas)
DO $$ 
BEGIN 
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_migrator') THEN
    CREATE ROLE role_migrator WITH LOGIN PASSWORD 'migrator_pass_123';
END IF;
END $$;
GRANT ALL PRIVILEGES ON SCHEMA public TO role_migrator;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO role_migrator;

-- 2. Rol Escritor (DML: INSERT, UPDATE, DELETE)
DO $$ 
BEGIN 
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_writer') THEN
    CREATE ROLE role_writer WITH LOGIN PASSWORD 'writer_pass_123';
END IF;
END $$;
GRANT USAGE ON SCHEMA public TO role_writer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO role_writer;

-- 3. Rol Lector (DML: SELECT en todas las tablas)
DO $$ 
BEGIN 
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_reader') THEN
    CREATE ROLE role_reader WITH LOGIN PASSWORD 'reader_pass_123';
END IF;
END $$;
GRANT USAGE ON SCHEMA public TO role_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO role_reader;

-- 4. Rol Operador (Acceso restringido únicamente a la tabla devices)
DO $$ 
BEGIN 
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_operator') THEN
    CREATE ROLE role_operator WITH LOGIN PASSWORD 'operator_pass_123';
END IF;
END $$;
GRANT USAGE ON SCHEMA public TO role_operator;
GRANT SELECT ON devices TO role_operator;