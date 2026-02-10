#!/usr/bin/env bash
# Open an interactive shell in a DSE container. Usage: ./scripts/shell.sh [service]
# Service names: dse-seed, dse-node-1, dse-node-2. Default: dse-seed.
# Example: ./scripts/shell.sh
# Example: ./scripts/shell.sh dse-node-1
cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
SERVICE="${1:-dse-seed}"
exec $COMPOSE_CMD exec -it "$SERVICE" bash
