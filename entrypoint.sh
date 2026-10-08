#!/bin/bash
cd /home/container || exit 1

# All SQL Server state (master db, user dbs, logs) lives in the server volume
mkdir -p /home/container/mssql

export MSSQL_TCP_PORT="${SERVER_PORT:-1433}"
export SQLCMDPASSWORD="${MSSQL_SA_PASSWORD}"

SQLCMD=/opt/mssql-tools18/bin/sqlcmd
[ -x "$SQLCMD" ] || SQLCMD=/opt/mssql-tools/bin/sqlcmd

# Pterodactyl startup: {{VAR}} -> ${VAR}
PARSED=$(echo "${STARTUP:-/opt/mssql/bin/sqlservr}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")
echo ":/home/container$ ${PARSED}"

bash -c "exec ${PARSED}" &
PID=$!

shutdown() {
    echo "Stopping SQL Server..."
    kill -TERM "$PID" 2>/dev/null
    wait "$PID"
    exit $?
}
trap shutdown INT TERM

# Panel console lines are executed as T-SQL against the local instance
while IFS= read -r line; do
    [ -z "$line" ] && continue
    "$SQLCMD" -S "127.0.0.1,${MSSQL_TCP_PORT}" -U sa -C -Q "$line" || true
done

wait "$PID"
