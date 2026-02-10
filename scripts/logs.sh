#!/usr/bin/env bash
# View DSE logs easily. Usage: ./scripts/logs.sh [service] [options]
# Examples:
#   ./scripts/logs.sh                    # Follow all DSE logs
#   ./scripts/logs.sh dse-seed           # Follow seed logs
#   ./scripts/logs.sh dse-seed --tail 50 # Last 50 lines of seed logs
#   ./scripts/logs.sh dse-seed -f        # Follow seed logs (same as default)
cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

SERVICE="${1:-}"
shift

if [ -z "$SERVICE" ]; then
    # Show all DSE services
    echo "📋 Showing logs for all DSE nodes (Ctrl+C to exit)..."
    $COMPOSE_CMD logs -f dse-seed dse-node-1 dse-node-2 "$@"
else
    # Show specific service
    echo "📋 Showing logs for $SERVICE (Ctrl+C to exit)..."
    if [ $# -eq 0 ]; then
        # Default to follow mode if no options provided
        $COMPOSE_CMD logs -f "$SERVICE"
    else
        $COMPOSE_CMD logs "$SERVICE" "$@"
    fi
fi
