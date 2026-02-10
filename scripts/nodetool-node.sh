#!/usr/bin/env bash
# Run nodetool on a specific node. Usage: ./scripts/nodetool-node.sh <service_or_container> <nodetool args>
# Service names: dse-seed, dse-node-1, dse-node-2. Example: ./scripts/nodetool-node.sh dse-seed status
# Example for second node: ./scripts/nodetool-node.sh dse-node-1 status
cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
CONTAINER="${1:-dse-seed}"
shift
$COMPOSE_CMD exec "$CONTAINER" nodetool "$@"
