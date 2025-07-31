-- *************************************************************************
-- IBM FileNet Content Manager ObjectStore preparation script for PostgreSQL
-- *************************************************************************
-- Usage:
-- Use psql command-line processor to execute the template file using -f option and user with administrative privileges
-- psql -h 127.0.0.1 -U dbaUser -f ./createOS1DB.sql

-- create user fn_fpos_user
CREATE ROLE fn_fpos_user WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Password1';

-- please modify location follow your requirement
create tablespace fn_fpos_db_tbs owner fn_fpos_user location '/var/lib/pgsql/data/fn_fpos_db/data';
create tablespace fn_fpos_dbindexts owner fn_fpos_user location '/var/lib/pgsql/data/fn_fpos_db/index';

grant create on tablespace fn_fpos_db_tbs to fn_fpos_user;
grant create on tablespace fn_fpos_dbindexts to fn_fpos_user;

-- create database fn_fpos_db
create database fn_fpos_db owner fn_fpos_user tablespace fn_fpos_db_tbs template template0 encoding UTF8 ;
revoke connect on database fn_fpos_db from public;
grant all privileges on database fn_fpos_db to fn_fpos_user;
grant connect, temp, create on database fn_fpos_db to fn_fpos_user;

-- create a schema for fn_fpos_db and set the default
-- connect to the respective database before executing the below commands
\connect fn_fpos_db;
CREATE SCHEMA IF NOT EXISTS AUTHORIZATION fn_fpos_user;
SET ROLE fn_fpos_user;
ALTER DATABASE fn_fpos_db SET search_path TO fn_fpos_user;
