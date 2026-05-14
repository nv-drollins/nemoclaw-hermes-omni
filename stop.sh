#!/usr/bin/env bash
# Stop the local Hermes Omni demo.
#
# By default this stops the web UI and the local vLLM model container.
# Keep the model warm with:
#   STOP_MODEL=false ./stop.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
PORT="${PORT:-8765}"
STOP_MODEL="${STOP_MODEL:-true}"
VLLM_CONTAINER="${VLLM_CONTAINER:-vllm-nemotron-omni}"
RUN_DIR="${RUN_DIR:-$ROOT/.run}"

stop_web() {
    local pids=""

    if [[ -f "$RUN_DIR/web.pid" ]]; then
        local pid
        pid=$(cat "$RUN_DIR/web.pid")
        if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
            pids="$pid"
        fi
    fi

    if command -v lsof >/dev/null 2>&1; then
        local port_pids
        port_pids=$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)
        if [[ -n "$port_pids" ]]; then
            pids="${pids}${pids:+ }${port_pids}"
        fi
    fi

    pids=$(tr ' ' '\n' <<<"$pids" | awk 'NF && !seen[$0]++' | xargs echo || true)
    if [[ -z "$pids" ]]; then
        echo "No web process found on port $PORT"
    else
        echo "Stopping web process(es): $pids"
        kill $pids 2>/dev/null || true
        sleep 2
        for pid in $pids; do
            if kill -0 "$pid" >/dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    fi

    rm -f "$RUN_DIR/web.pid"
}

stop_model() {
    if [[ "$STOP_MODEL" != "true" ]]; then
        echo "STOP_MODEL=false; leaving vLLM running."
        return 0
    fi

    if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' | grep -qx "$VLLM_CONTAINER"; then
        echo "Stopping local vLLM container: $VLLM_CONTAINER"
        docker stop "$VLLM_CONTAINER" >/dev/null 2>&1 || true
    else
        echo "No vLLM container found: $VLLM_CONTAINER"
    fi
}

stop_web
stop_model
echo "Stopped."
