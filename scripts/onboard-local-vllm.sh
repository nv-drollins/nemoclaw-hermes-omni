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

if ! command -v nemoclaw >/dev/null 2>&1; then
  cat >&2 <<EOF
Missing nemoclaw CLI.

Start the local vLLM model first:
  START_WEB=false ./start.sh

Then install NemoClaw/OpenShell against that local vLLM endpoint:
  curl -fsSL https://www.nvidia.com/nemoclaw.sh -o /tmp/nemoclaw.sh
  NEMOCLAW_EXPERIMENTAL=1 \\
  NEMOCLAW_PROVIDER=vllm \\
  NEMOCLAW_MODEL=$MODEL_ID \\
  NEMOCLAW_SANDBOX_NAME=$SANDBOX \\
  NEMOCLAW_LOCAL_INFERENCE_TIMEOUT=$NEMOCLAW_LOCAL_INFERENCE_TIMEOUT \\
    bash /tmp/nemoclaw.sh --non-interactive --yes-i-accept-third-party-software --fresh

After that, rerun:
  bash scripts/onboard-local-vllm.sh
EOF
  exit 1
fi

if ! curl -fsS http://127.0.0.1:8000/v1/models | grep -Fq "$MODEL_ID"; then
  cat >&2 <<EOF
Local vLLM is not serving $MODEL_ID on http://127.0.0.1:8000/v1.

Start it first with:
  START_WEB=false ./start.sh
EOF
  exit 1
fi

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
