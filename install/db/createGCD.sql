-- *****************************************************************
-- IBM FileNet Content Manager GCD preparation script for PostgreSQL
-- *****************************************************************
-- Usage:
-- Use psql command-line processor to execute the template file using -f option and user with administrative privileges
-- psql -h 127.0.0.1 -U dbaUser -f ./createGCDDB.sql

-- create user fn_gcd_user
CREATE ROLE fn_gcd_user WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Password1';

-- please modify location follow your requirement
create tablespace fn_gcd_db_tbs owner fn_gcd_user location '/var/lib/pgsql/data/fn_gcd_db';
grant create on tablespace fn_gcd_db_tbs to fn_gcd_user;

-- create database fn_gcd_db
create database fn_gcd_db owner fn_gcd_user tablespace fn_gcd_db_tbs template template0 encoding UTF8 ;
revoke connect on database fn_gcd_db from public;
grant all privileges on database fn_gcd_db to fn_gcd_user;
grant connect, temp, create on database fn_gcd_db to fn_gcd_user;

-- create a schema for fn_gcd_db and set the default
-- connect to the respective database before executing the below commands
\connect fn_gcd_db;
CREATE SCHEMA IF NOT EXISTS AUTHORIZATION fn_gcd_user;
SET ROLE fn_gcd_user;
ALTER DATABASE fn_gcd_db SET search_path TO fn_gcd_user;


