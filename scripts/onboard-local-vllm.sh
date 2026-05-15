#!/usr/bin/env bash
# Onboard Hermes against the local vLLM endpoint used by this demo.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)

SANDBOX="${SANDBOX:-my-hermes-local}"
MODEL_ID="${MODEL_ID:-nvidia/nemotron-3-nano-omni-30b-a3b-reasoning}"
NEMOCLAW_LOCAL_INFERENCE_TIMEOUT="${NEMOCLAW_LOCAL_INFERENCE_TIMEOUT:-600}"

if [ -n "${NEMOCLAW_INSTALL_REF:-}" ]; then
  echo "NEMOCLAW_INSTALL_REF=${NEMOCLAW_INSTALL_REF} is set; this script uses the currently installed nemoclaw CLI."
fi
bash "$ROOT/scripts/ensure-sudo.sh"

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export NEMOCLAW_EXPERIMENTAL=1
export NEMOCLAW_PROVIDER="${NEMOCLAW_PROVIDER:-vllm}"
export NEMOCLAW_MODEL="$MODEL_ID"
export NEMOCLAW_LOCAL_INFERENCE_TIMEOUT

nemoclaw onboard \
  --non-interactive \
  --fresh \
  --name "$SANDBOX" \
  --agent hermes \
  --no-gpu \
  --no-sandbox-gpu \
  --yes \
  --yes-i-accept-third-party-software
