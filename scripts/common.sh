#!/usr/bin/env bash
# Set COMPOSE_CMD for docker compose. Source from other scripts.
# Uses CONTAINER_RUNTIME from environment or .env (docker | colima). Default: docker.
# Colima provides a Docker-compatible daemon; set CONTAINER_RUNTIME=colima to require Colima and use docker compose.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load CONTAINER_RUNTIME from .env if not set
if [ -z "${CONTAINER_RUNTIME:-}" ] && [ -f "$REPO_ROOT/.env" ]; then
  val=$(grep -E '^CONTAINER_RUNTIME=' "$REPO_ROOT/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' | xargs)
  [ -n "$val" ] && CONTAINER_RUNTIME="$val"
fi
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

case "$CONTAINER_RUNTIME" in
  colima)
    if ! command -v colima >/dev/null 2>&1; then
      echo "CONTAINER_RUNTIME=colima but 'colima' not found. Install with: brew install colima" >&2
      exit 1
    fi
    if ! colima status 2>&1 | grep -q "colima is running"; then
      echo "CONTAINER_RUNTIME=colima but Colima is not running. Start with: colima start" >&2
      exit 1
    fi
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
      COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
      COMPOSE_CMD="docker-compose"
    else
      echo "CONTAINER_RUNTIME=colima but neither 'docker compose' nor 'docker-compose' found." >&2
      exit 1
    fi
    CONTAINER_EXEC="docker exec"
    ;;
  docker)
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
      COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
      COMPOSE_CMD="docker-compose"
    else
      echo "CONTAINER_RUNTIME=docker but neither 'docker compose' nor 'docker-compose' found." >&2
      exit 1
    fi
    CONTAINER_EXEC="docker exec"
    ;;
  *)
    echo "CONTAINER_RUNTIME must be 'docker' or 'colima', got: $CONTAINER_RUNTIME" >&2
    exit 1
    ;;
esac

export COMPOSE_CMD CONTAINER_EXEC CONTAINER_RUNTIME
