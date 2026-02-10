#!/usr/bin/env bash
# Run cqlsh on the seed node. Usage: ./scripts/cqlsh.sh [cqlsh args]
# For -f <file>, use a path relative to repo root; it is mounted at /workspace in the container.
# IMPORTANT: Run this script directly, do NOT use backticks (`) around it.
set -e
cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

# Rewrite -f <path> to -f /workspace/<path> when path exists on host so container can read it
CQLSH_ARGS=()
while [ $# -gt 0 ]; do
  if [ "$1" = "-f" ] && [ -n "${2:-}" ]; then
    if [ -f "$REPO_ROOT/$2" ]; then
      CQLSH_ARGS+=(-f "/workspace/$2")
    else
      echo "Error: File not found: $REPO_ROOT/$2" >&2
      exit 1
    fi
    shift 2
  else
    CQLSH_ARGS+=("$1")
    shift
  fi
done

# Use -T flag to disable TTY allocation when stdin is not a terminal (e.g., heredoc, pipe)
if [ -t 0 ]; then
    # stdin is a terminal, use normal exec
    # Use -T flag to disable TTY allocation when stdin is not a terminal (e.g., heredoc, pipe)
if [ -t 0 ]; then
    # stdin is a terminal, use normal exec
    $COMPOSE_CMD exec dse-seed cqlsh "${CQLSH_ARGS[@]}"
else
    # stdin is not a terminal (heredoc/pipe), disable TTY
    $COMPOSE_CMD exec -T dse-seed cqlsh "${CQLSH_ARGS[@]}"
fi
else
    # stdin is not a terminal (heredoc/pipe), disable TTY
    $COMPOSE_CMD exec -T dse-seed cqlsh "${CQLSH_ARGS[@]}"
fi
