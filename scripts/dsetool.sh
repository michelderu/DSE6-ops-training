#!/usr/bin/env bash
# Run dsetool on the seed node. Usage: ./scripts/dsetool.sh <dsetool args>
# Example: ./scripts/dsetool.sh status
cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
$COMPOSE_CMD exec dse-seed dsetool "$@"
