#!/bin/bash
cd /home/container || exit 1

# All SQL Server state (master db, user dbs, logs) lives in the server volume
mkdir -p /home/container/mssql

export MSSQL_TCP_PORT="${SERVER_PORT:-1433}"
export SQLCMDPASSWORD="${MSSQL_SA_PASSWORD}"

SQLCMD=/opt/mssql-tools18/bin/sqlcmd
[ -x "$SQLCMD" ] || SQLCMD=/opt/mssql-tools/bin/sqlcmd

# Pterodactyl startup: {{VAR}} -> ${VAR}. The string is run as a script, not
# expanded through `eval echo` first: the panel may prefix it with commands of
# its own (a console banner), and `eval echo` would run those inside a command
# substitution and hand their output back as the command to execute.
MODIFIED_STARTUP=$(printf '%s' "${STARTUP:-/opt/mssql/bin/sqlservr}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

# Own session, so shutdown can signal bash and sqlservr together. stdin stays
# with this script: console lines are T-SQL, read below.
setsid bash -c "${MODIFIED_STARTUP}" </dev/null &
PID=$!

shutdown() {
    echo "Stopping SQL Server..."
    kill -TERM -- "-$PID" 2>/dev/null || kill -TERM "$PID" 2>/dev/null
    wait "$PID"
    exit $?
}
trap shutdown INT TERM

# The customer's own database, created once SQL Server answers, and made sa's
# default so SSMS opens straight into it. Idempotent: an existing database is
# left alone, so this runs on every start. The name goes into T-SQL, so it is
# checked against a strict identifier shape first rather than quoted.
provision() {
    local db="${MSSQL_DATABASE:-}"
    [ -z "$db" ] && return 0
    if ! [[ "$db" =~ ^[A-Za-z][A-Za-z0-9_]{0,63}$ ]]; then
        echo "Renode: MSSQL_DATABASE '${db}' is not a plain name (letters, digits, _); not created."
        return 0
    fi
    for _ in $(seq 1 150); do
        "$SQLCMD" -S "127.0.0.1,${MSSQL_TCP_PORT}" -U sa -C -b -l 2 -Q "SELECT 1" >/dev/null 2>&1 && break
        kill -0 "$PID" 2>/dev/null || return 0
        sleep 2
    done
    "$SQLCMD" -S "127.0.0.1,${MSSQL_TCP_PORT}" -U sa -C -b -h -1 -Q "SET NOCOUNT ON;
IF DB_ID(N'${db}') IS NULL
BEGIN
    CREATE DATABASE [${db}];
    ALTER LOGIN [sa] WITH DEFAULT_DATABASE = [${db}];
    PRINT 'Renode: Created database ${db} (default database for sa).';
END
ELSE
    PRINT 'Renode: Database ${db} is ready.';" \
        || echo "Renode: Could not create database ${db}: was the sa password changed with ALTER LOGIN?"
}
provision &

# Panel console lines are executed as T-SQL against the local instance. In the
# background, so the container lives exactly as long as SQL Server does: a
# server that fails to start must exit, or Wings shows "starting" for ever.
# stdin is passed explicitly; a background job would otherwise get /dev/null.
exec 3<&0
while IFS= read -r line <&3; do
    [ -z "$line" ] && continue
    "$SQLCMD" -S "127.0.0.1,${MSSQL_TCP_PORT}" -U sa -C -Q "$line" || true
done &

wait "$PID"
exit $?
