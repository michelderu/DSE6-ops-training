#!/usr/bin/env bash
# View DSE system.log from inside containers (containers don't log much to stdout).
# Usage: ./scripts/logs.sh [service] [options]
# Examples:
#   ./scripts/logs.sh                    # Follow dse-seed system.log
#   ./scripts/logs.sh dse-seed            # Follow seed system.log
#   ./scripts/logs.sh dse-seed --tail 50  # Last 50 lines of seed system.log
#   ./scripts/logs.sh dse-node-1         # Follow node-1 system.log
LOG_PATH="/var/log/cassandra/system.log"

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

# First arg is service name unless it's --tail
SERVICE="dse-seed"
if [ -n "${1:-}" ] && [ "$1" != "--tail" ]; then
    SERVICE="$1"
    shift
fi

# Parse --tail N (optional)
TAIL_LINES=""
while [ $# -gt 0 ]; do
    case "$1" in
        --tail)
            TAIL_LINES="${2:-}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "$TAIL_LINES" ]; then
    echo "📋 Following $LOG_PATH on $SERVICE (Ctrl+C to exit)..."
    $COMPOSE_CMD exec "$SERVICE" tail -f "$LOG_PATH"
else
    echo "📋 Last $TAIL_LINES lines of $LOG_PATH on $SERVICE:"
    $COMPOSE_CMD exec -T "$SERVICE" tail -n "$TAIL_LINES" "$LOG_PATH"
fi
