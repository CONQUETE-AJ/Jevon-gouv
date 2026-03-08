#!/usr/bin/env bash

set -euo pipefail

PG_INIT_DB="${PG_INIT_DB:-postgres}"
POSTGRES_USER_NAME="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
OM_DATABASE="${OM_DATABASE:-openmetadata_db}"
OM_USER="${DB_USER:-openmetadata_user}"
OM_USER_PASSWORD="${DB_USER_PASSWORD:-openmetadata_password}"
AIRFLOW_DB="${AIRFLOW_DB:-airflow_db}"
AIRFLOW_USER="${AIRFLOW_DB_USER:-airflow_user}"
AIRFLOW_USER_PASSWORD="${AIRFLOW_DB_PASSWORD:-airflow_pass}"

export PGPASSWORD="$POSTGRES_PASSWORD"

escape_sql() {
  printf "%s" "$1" | sed "s/'/''/g"
}

psql_cmd=(psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER_NAME" -d "$PG_INIT_DB")

db_exists() {
  local db_name=$1
  "${psql_cmd[@]}" -tAc "SELECT 1 FROM pg_database WHERE datname='$(escape_sql "$db_name")'" | grep -q 1
}

role_exists() {
  local role_name=$1
  "${psql_cmd[@]}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$(escape_sql "$role_name")'" | grep -q 1
}

create_role_if_missing() {
  local user=$1
  local password=$2
  if role_exists "$user"; then
    "${psql_cmd[@]}" -c "ALTER ROLE \"$user\" WITH LOGIN PASSWORD '$(escape_sql "$password")';"
  else
    "${psql_cmd[@]}" -c "CREATE ROLE \"$user\" LOGIN PASSWORD '$(escape_sql "$password")';"
  fi
}

create_db_if_missing() {
  local db_name=$1
  local owner=$2
  if ! db_exists "$db_name"; then
    "${psql_cmd[@]}" -c "CREATE DATABASE \"$db_name\" OWNER \"$owner\";"
  fi
  "${psql_cmd[@]}" -c "ALTER DATABASE \"$db_name\" OWNER TO \"$owner\";"
  "${psql_cmd[@]}" -c "GRANT ALL PRIVILEGES ON DATABASE \"$db_name\" TO \"$owner\";"

  local db_psql_cmd=(psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER_NAME" -d "$db_name")
  "${db_psql_cmd[@]}" -c "ALTER SCHEMA public OWNER TO \"$owner\";"
  "${db_psql_cmd[@]}" -c "GRANT ALL PRIVILEGES ON SCHEMA public TO \"$owner\";"
  "${db_psql_cmd[@]}" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$owner\";"
  "${db_psql_cmd[@]}" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$owner\";"
  "${db_psql_cmd[@]}" -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO \"$owner\";"
}

create_role_if_missing "$OM_USER" "$OM_USER_PASSWORD"
create_role_if_missing "$AIRFLOW_USER" "$AIRFLOW_USER_PASSWORD"
create_db_if_missing "$OM_DATABASE" "$OM_USER"
create_db_if_missing "$AIRFLOW_DB" "$AIRFLOW_USER"

unset PGPASSWORD
