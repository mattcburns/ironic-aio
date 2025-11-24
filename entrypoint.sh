#!/usr/bin/env bash
set -euo pipefail

IRONIC_CONFIG=${IRONIC_CONFIG:-/app/ironic.conf}

# Extract sqlite DB URL from config; fall back to standard path
DB_URL=$(awk -F'=' '/^\s*\[database\]/{flag=1; next} /^\s*\[/{flag=0} flag && /^\s*connection\s*=/{gsub(/ /, "", $2); print $2}' "$IRONIC_CONFIG" || true)

DB_PATH="/app/ironic.sqlite"
if [[ -n "${DB_URL:-}" && "$DB_URL" == sqlite:* ]]; then
  case "$DB_URL" in
    sqlite:////*) DB_PATH="/${DB_URL#sqlite:////}" ;;
    sqlite:///*)  DB_PATH="/${DB_URL#sqlite:///}" ;;
    sqlite://*)   DB_PATH="/${DB_URL#sqlite://}" ;;
  esac
fi

# Normalize multiple leading slashes to one
DB_PATH="$(echo "$DB_PATH" | sed -E 's#^/+#/#')"

# Sanity checks for mounts and permissions
if [[ ! -r "$IRONIC_CONFIG" ]]; then
  echo "[ironic-entrypoint] ERROR: Config file '$IRONIC_CONFIG' is not readable or is missing."
  echo "Ensure you have mounted ironic.conf into the container at $IRONIC_CONFIG."
  exit 1
fi

# If the DB path is a directory, fail fast with a helpful hint
if [[ -d "$DB_PATH" ]]; then
  echo "[ironic-entrypoint] ERROR: Expected SQLite database file at '$DB_PATH' but found a directory."
  echo "This commonly occurs when bind-mounting a file path that didn't exist on the host, causing Docker to create a directory instead."
  echo "Fix on the host, then restart the container:"
  echo "  rm -rf ironic.sqlite && touch ironic.sqlite"
  exit 1
fi

# Ensure the parent directory exists
mkdir -p "$(dirname "$DB_PATH")"

# If the DB does not exist yet, verify we can write to the parent directory
if [[ ! -e "$DB_PATH" && ! -w "$(dirname "$DB_PATH")" ]]; then
  echo "[ironic-entrypoint] ERROR: Cannot write to '$(dirname "$DB_PATH")' to create the SQLite database. Check mount permissions."
  exit 1
fi

# If the DB exists but is not a regular file or is not writable, fail
if [[ -e "$DB_PATH" && ! -f "$DB_PATH" ]]; then
  echo "[ironic-entrypoint] ERROR: '$DB_PATH' exists but is not a regular file."
  ls -ld "$DB_PATH" || true
  exit 1
fi
if [[ -f "$DB_PATH" && ! -w "$DB_PATH" ]]; then
  echo "[ironic-entrypoint] ERROR: SQLite database file '$DB_PATH' is not writable. Check file and mount permissions."
  ls -l "$DB_PATH" || true
  exit 1
fi

# Check if DB needs initialization (doesn't exist or is empty/invalid)
NEEDS_INIT=false
if [[ ! -f "$DB_PATH" ]]; then
  NEEDS_INIT=true
elif [[ ! -s "$DB_PATH" ]]; then
  # File exists but is empty (0 bytes)
  NEEDS_INIT=true
fi

if [[ "$NEEDS_INIT" == "true" ]]; then
  echo "[ironic-entrypoint] No existing DB at $DB_PATH. Creating schema..."
  ironic-dbsync --config-file "$IRONIC_CONFIG" create_schema
else
  echo "[ironic-entrypoint] Existing DB found at $DB_PATH. Running upgrade..."
  ironic-dbsync --config-file "$IRONIC_CONFIG" upgrade || echo "[ironic-entrypoint] Upgrade failed or not required; continuing."
fi

echo "[ironic-entrypoint] Launching single-process Ironic (API + Conductor) ..."
exec ironic --config-file "$IRONIC_CONFIG"
