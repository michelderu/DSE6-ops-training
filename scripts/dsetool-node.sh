#!/usr/bin/env bash
# Run dsetool on a specific node. Usage: ./scripts/dsetool-node.sh <service_or_container> <dsetool args>
# Service names: dse-seed, dse-node-1, dse-node-2. Example: ./scripts/dsetool-node.sh dse-seed status
# Example for second node: ./scripts/dsetool-node.sh dse-node-1 status
cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
CONTAINER="${1:-dse-seed}"
shift
$COMPOSE_CMD exec "$CONTAINER" dsetool "$@"
