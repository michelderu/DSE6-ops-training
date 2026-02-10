#!/usr/bin/env bash
# Run nodetool on the seed node. Usage: ./scripts/nodetool.sh <nodetool args>
# Example: ./scripts/nodetool.sh status
cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
$COMPOSE_CMD exec dse-seed nodetool "$@"
