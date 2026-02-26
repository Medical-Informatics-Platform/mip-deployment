#!/bin/sh
set -eu

PLATFORM_DB_NAME="${PLATFORM_DB_NAME:-portal}"
ADMIN_DB="${POSTGRES_DB:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

if [ -z "${PLATFORM_DB_USER:-}" ] || [ -z "${PLATFORM_DB_PASSWORD:-}" ]; then
  echo "platform DB credentials missing; skipping bootstrap" >&2
  exit 0
fi

PLATFORM_DB_NAME_ESC=$(printf "%s" "${PLATFORM_DB_NAME}" | sed "s/'/''/g")
PLATFORM_DB_USER_ESC=$(printf "%s" "${PLATFORM_DB_USER}" | sed "s/'/''/g")
PLATFORM_DB_PASSWORD_ESC=$(printf "%s" "${PLATFORM_DB_PASSWORD}" | sed "s/'/''/g")

export PGPASSWORD="${POSTGRES_PASSWORD:-}"

echo "Waiting for PostgreSQL to accept connections..."
until pg_isready --username "${POSTGRES_USER}" --port "${POSTGRES_PORT}" >/dev/null 2>&1; do
  sleep 2
done

DB_EXISTS=$(psql --username "${POSTGRES_USER}" --dbname "${ADMIN_DB}" --port "${POSTGRES_PORT}" -tAc "SELECT 1 FROM pg_database WHERE datname='${PLATFORM_DB_NAME_ESC}'" || true)

if [ "${DB_EXISTS}" != "1" ]; then
  echo "Creating database ${PLATFORM_DB_NAME}"
  createdb --username "${POSTGRES_USER}" --port "${POSTGRES_PORT}" "${PLATFORM_DB_NAME}"
else
  echo "Database ${PLATFORM_DB_NAME} already exists"
fi

echo "Ensuring role ${PLATFORM_DB_USER} exists (with SUPERUSER)"
psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${ADMIN_DB}" \
  --port "${POSTGRES_PORT}" <<EOFSQL
DO \$\$
DECLARE
  platform_user text := '${PLATFORM_DB_USER_ESC}';
  platform_password text := '${PLATFORM_DB_PASSWORD_ESC}';
BEGIN
  IF platform_user IS NULL OR platform_user = '' THEN
    RAISE NOTICE 'PLATFORM_DB_USER empty, skipping platform bootstrap';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = platform_user) THEN
    EXECUTE format('CREATE ROLE %I SUPERUSER LOGIN PASSWORD %L', platform_user, platform_password);
  ELSE
    EXECUTE format('ALTER ROLE %I WITH SUPERUSER LOGIN PASSWORD %L', platform_user, platform_password);
  END IF;
END;
\$\$;
EOFSQL

psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${ADMIN_DB}" \
  --port "${POSTGRES_PORT}" <<EOFSQL
DO \$\$
DECLARE
  platform_db text := '${PLATFORM_DB_NAME_ESC}';
  platform_user text := '${PLATFORM_DB_USER_ESC}';
BEGIN
  IF platform_user IS NULL OR platform_user = '' THEN
    RETURN;
  END IF;

  EXECUTE format('ALTER DATABASE %I OWNER TO %I', platform_db, platform_user);
  EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', platform_db);
  EXECUTE format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', platform_db, platform_user);
END;
\$\$;
EOFSQL

psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${PLATFORM_DB_NAME}" \
  --port "${POSTGRES_PORT}" <<EOFSQL
DO \$\$
DECLARE
  platform_user text := '${PLATFORM_DB_USER_ESC}';
BEGIN
  IF platform_user IS NULL OR platform_user = '' THEN
    RETURN;
  END IF;

  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO %I', platform_user);
  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO %I', platform_user);
  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO %I', platform_user);
END;
\$\$;
EOFSQL
