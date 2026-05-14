#!/usr/bin/env bash
# Apply the Hermes Omni demo skills, policy, scripts, and memory file to an
# already-created NemoClaw Hermes sandbox.
set -euo pipefail

SANDBOX="${SANDBOX:-my-hermes-local}"
HERE=$(cd "$(dirname "$0")/.." && pwd)

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require_cmd docker
require_cmd openshell
require_cmd nemoclaw

if ! nemoclaw "$SANDBOX" status >/dev/null 2>&1; then
    echo "Sandbox '$SANDBOX' is not ready." >&2
    exit 1
fi

container=$(
    docker ps --format '{{.Names}}' |
        awk -v prefix="openshell-${SANDBOX}-" 'index($0, prefix) == 1 { print; exit }'
)

if [[ -z "$container" ]]; then
    echo "Could not find the OpenShell Docker container for sandbox '$SANDBOX'." >&2
    exit 1
fi

echo "Using sandbox container: $container"

docker exec "$container" bash -lc '
    set -euo pipefail
    mkdir -p \
        /sandbox/.hermes/workspace \
        /sandbox/.hermes/memories \
        /sandbox/.hermes/skills/video-analyze \
        /sandbox/.hermes/skills/jargon-lookup
    sed -i "s|^  timeout: 180$|  timeout: 1800|" /sandbox/.hermes/config.yaml
    sed -i "s|nvidia/nemotron-3-super-120b-a12b|nvidia/nemotron-3-nano-omni-30b-a3b-reasoning|g" /sandbox/.hermes/config.yaml
'

docker cp "$HERE/scripts/omni-video-analyze.py" "$container:/sandbox/.hermes/workspace/omni-video-analyze.py"
docker cp "$HERE/scripts/lookup-jargon.py" "$container:/sandbox/.hermes/workspace/lookup-jargon.py"
docker cp "$HERE/memories/SOUL.md" "$container:/sandbox/.hermes/SOUL.md"
docker cp "$HERE/memories/SOUL.md" "$container:/sandbox/.hermes/memories/SOUL.md"
docker cp "$HERE/skills/video-analyze/SKILL.md" "$container:/sandbox/.hermes/skills/video-analyze/SKILL.md"
docker cp "$HERE/skills/jargon-lookup/SKILL.md" "$container:/sandbox/.hermes/skills/jargon-lookup/SKILL.md"

docker exec "$container" bash -lc '
    set -euo pipefail
    chmod +x /sandbox/.hermes/workspace/omni-video-analyze.py /sandbox/.hermes/workspace/lookup-jargon.py
    chown -R sandbox:sandbox \
        /sandbox/.hermes/workspace \
        /sandbox/.hermes/memories \
        /sandbox/.hermes/SOUL.md \
        /sandbox/.hermes/skills/video-analyze \
        /sandbox/.hermes/skills/jargon-lookup
'

raw_policy=$(mktemp)
current_policy=$(mktemp)
trap 'rm -f "$raw_policy" "$current_policy"' EXIT

openshell policy get "$SANDBOX" --full > "$raw_policy"
awk '/^---$/{seen=1; next} seen' "$raw_policy" > "$current_policy"
cat "$HERE/policy/hermes-omni-lookup.yaml" >> "$current_policy"
openshell policy set --policy "$current_policy" "$SANDBOX"

echo "Demo setup applied to sandbox '$SANDBOX'."
