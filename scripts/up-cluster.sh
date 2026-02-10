#!/usr/bin/env bash
# Bring up DSE cluster in correct order: seed first, then node-1, then node-2 (3 nodes total).
# Compose healthchecks (DSE startup complete in logs) enforce readiness; no script wait needed.
# Usage: from repo root, ./scripts/up-cluster.sh

set -e
cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

echo "==> Starting seed node ($CONTAINER_RUNTIME)..."
$COMPOSE_CMD up -d dse-seed

echo "==> Starting dse-node-1 (Compose waits for seed healthy)..."
$COMPOSE_CMD up -d dse-node-1

echo "==> Starting dse-node-2 (Compose waits for node-1 healthy)..."
$COMPOSE_CMD up -d dse-node-2

echo ""
echo "==> Cluster is coming up. Wait ~1–2 minutes for all nodes to join, then:"
echo "    nodetool status:  ./scripts/nodetool.sh status"
echo "    cqlsh:            ./scripts/cqlsh.sh"
echo ""
