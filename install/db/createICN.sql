-- *******************************************************
-- IBM Content Navigator preparation script for PostgreSQL
-- *******************************************************
-- Usage:
-- Use psql command-line processor to execute the template file using -f option and user with administrative privileges
-- psql -h 127.0.0.1 -U dbaUser -f ./createICNDB.sql

-- create user icn_user
CREATE ROLE icn_user WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Password1';

-- please modify location follow your requirement
create tablespace icn_db_ts owner icn_user location '/var/lib/pgsql/data/icn_db';
grant create on tablespace icn_db_ts to icn_user;

-- create database icn_db
create database icn_db owner icn_user tablespace icn_db_ts template template0 encoding UTF8 ;
revoke connect on database icn_db from public;
grant all privileges on database icn_db to icn_user;
grant connect, temp, create on database icn_db to icn_user;

-- create a schema for icn_db and set the default
-- connect to the respective database before executing the below commands
\connect icn_db;
CREATE SCHEMA IF NOT EXISTS icn_db_schema AUTHORIZATION icn_user;
SET ROLE icn_user;
ALTER DATABASE icn_db SET search_path TO icn_db_schema;
