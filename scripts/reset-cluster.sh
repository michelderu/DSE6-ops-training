#!/usr/bin/env bash
# Reset the DSE cluster: stop containers, remove data, optionally restart.
# Usage: ./scripts/reset-cluster.sh [--restart]
#   --restart: After cleanup, restart the cluster
#   --keep-config: Keep config/ directory (default: keep it)
#   --all: Remove everything including config/ directory
cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

RESTART=false
KEEP_CONFIG=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --restart)
            RESTART=true
            shift
            ;;
        --all)
            KEEP_CONFIG=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--restart] [--all]"
            echo "  --restart: Restart cluster after cleanup"
            echo "  --all: Remove config/ directory too (default: keep it)"
            exit 1
            ;;
    esac
done

echo "🛑 Stopping cluster..."
$COMPOSE_CMD down

echo "🧹 Cleaning up data directories..."
if [ -d "data" ]; then
    rm -rf data/*
    echo "   ✓ Removed data/ directory contents"
else
    echo "   ℹ No data/ directory found"
fi

if [ "$KEEP_CONFIG" = false ]; then
    echo "🧹 Cleaning up config directory..."
    if [ -d "config" ]; then
        rm -rf config/*
        echo "   ✓ Removed config/ directory contents"
    fi
fi

echo ""
echo "✅ Cluster reset complete!"
echo ""

if [ "$RESTART" = true ]; then
    echo "🚀 Restarting cluster..."
    ./scripts/up-cluster.sh
else
    echo "💡 To restart the cluster, run: ./scripts/up-cluster.sh"
fi
