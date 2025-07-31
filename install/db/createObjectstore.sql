-- *************************************************************************
-- IBM FileNet Content Manager ObjectStore preparation script for PostgreSQL
-- *************************************************************************
-- Usage:
-- Use psql command-line processor to execute the template file using -f option and user with administrative privileges
-- psql -h 127.0.0.1 -U dbaUser -f ./createOS1DB.sql

-- create user fn_os_user
CREATE ROLE fn_os_user WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Password1';

-- please modify location follow your requirement
create tablespace fn_os_db_tbs owner fn_os_user location '/var/lib/pgsql/data/fn_os_db/data';
create tablespace fn_os_dbindexts owner fn_os_user location '/var/lib/pgsql/data/fn_os_db/index';

grant create on tablespace fn_os_db_tbs to fn_os_user;
grant create on tablespace fn_os_dbindexts to fn_os_user;

-- create database fn_os_db
create database fn_os_db owner fn_os_user tablespace fn_os_db_tbs template template0 encoding UTF8 ;
revoke connect on database fn_os_db from public;
grant all privileges on database fn_os_db to fn_os_user;
grant connect, temp, create on database fn_os_db to fn_os_user;

-- create a schema for fn_os_db and set the default
-- connect to the respective database before executing the below commands
\connect fn_os_db;
CREATE SCHEMA IF NOT EXISTS AUTHORIZATION fn_os_user;
SET ROLE fn_os_user;
ALTER DATABASE fn_os_db SET search_path TO fn_os_user;
