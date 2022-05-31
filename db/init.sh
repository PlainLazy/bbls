#!/bin/bash
set -e

# юзер и БД
psql -v ON_ERROR_STOP=1 -U $POSTGRES_USER <<-EOSQL
    CREATE DATABASE $DB_NAME;
    CREATE USER $DB_USER WITH password '$DB_PASS';
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOSQL

# накат схемы
psql -U $DB_USER $DB_NAME < /var/schema.sql

# админ для админки
psql -v ON_ERROR_STOP=1 -U $POSTGRES_USER $DB_NAME <<-EOSQL
    insert into "admin"."config" ("key", "value") values ('admin_passw_salt', md5(random()::text));
    select "admin"."_create_new_admin"('$ADM_USER', '$ADM_PASS');
EOSQL