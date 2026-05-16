# NemoClaw Hermes Omni Demo on DGX Spark

This repo packages the Hermes Omni demo so it can run locally on a DGX Spark:

- Hermes Agent runs in a NemoClaw/OpenShell sandbox.
- Nemotron Omni runs locally with vLLM on the Spark GPU.
- The browser UI runs on port `8765`.

The tested local model is:

```text
nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4
```

The runtime exposes it as:

```text
nvidia/nemotron-3-nano-omni-30b-a3b-reasoning
```

## First Deploy

Run these commands on the Spark.

```bash
git clone https://github.com/nv-drollins/nemoclaw-hermes-omni.git
cd nemoclaw-hermes-omni
chmod +x start.sh stop.sh restart.sh scripts/*.sh
```

Install host prerequisites:

```bash
bash scripts/install-host-prereqs.sh
```

The helper installs `git`, `curl`, `ffmpeg`, `ffprobe`, `pdftoppm`,
`lsof`, Python/venv, and Node/npm. The start script also expects Docker with
NVIDIA GPU container support, which is included on the DGX Spark software image
used for this demo. On a clean Ubuntu host without Docker, run:

```bash
bash scripts/install-docker-nvidia-toolkit.sh
```

These setup helpers do **not** require passwordless sudo. They call
`scripts/ensure-sudo.sh`, which prompts for your sudo password when needed.
Run first-time setup from a terminal or SSH session with a TTY so the prompt can
appear. For example:

```bash
ssh -t nvidia@<spark-ip>
```

Download the local Omni model. If the model is gated, accept the model terms in
your browser first, then provide `HF_TOKEN` for the download helper:

```bash
# either export it once for this terminal
export HF_TOKEN="hf_..."
bash scripts/download-model.sh

# or pass it only to the download command
HF_TOKEN="hf_..." bash scripts/download-model.sh
```

The token is needed for `scripts/download-model.sh`, not for `./start.sh`.
If you store `HF_TOKEN` in `.bashrc`, place it above Ubuntu's early
non-interactive `return` guard, or non-interactive deploy scripts will not see
it. The download helper creates its own Hugging Face CLI virtualenv at
`$HOME/.local/share/hf-download-venv`, so a clean box does not need a global
`hf` command installed first. Override the target location with `MODEL_DIR=...`
if needed.

Start only the local vLLM model server:

```bash
START_WEB=false ./start.sh
```

Install NemoClaw/OpenShell against the local vLLM endpoint. This avoids the
upstream installer's default non-interactive cloud-provider onboarding path,
which can fail on a clean box with `NVIDIA_API_KEY is required` before the
Hermes local-vLLM sandbox is configured.

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh -o /tmp/nemoclaw.sh
NEMOCLAW_EXPERIMENTAL=1 \
NEMOCLAW_PROVIDER=vllm \
NEMOCLAW_MODEL=nvidia/nemotron-3-nano-omni-30b-a3b-reasoning \
NEMOCLAW_SANDBOX_NAME=my-hermes-local \
NEMOCLAW_LOCAL_INFERENCE_TIMEOUT=600 \
  bash /tmp/nemoclaw.sh --non-interactive --yes-i-accept-third-party-software --fresh
```

Make sure the new CLIs are on your path:

```bash
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
```

Onboard the Hermes sandbox against local vLLM:

```bash
bash scripts/onboard-local-vllm.sh
```

The onboarding wrapper warms up sudo first. This avoids a common fresh-install
failure where NemoClaw's preflight needs to run a host-level port check and
`sudo` cannot prompt from a non-interactive shell.

Apply the demo skills, scripts, memory, and lookup policy:

```bash
SANDBOX=my-hermes-local bash scripts/apply-demo-setup.sh
```

Start the full demo:

```bash
./start.sh
```

Open:

```text
http://<spark-ip>:8765
```

### NemoClaw version pinning

Leave `NEMOCLAW_INSTALL_REF` unset for the current NemoClaw installer. To
compare against a previous known demo lane, add it to the local-vLLM install
command above, for example `NEMOCLAW_INSTALL_REF=v0.0.38`.

Check what is installed before debugging a sandbox issue:

```bash
nemoclaw --version
openshell --version
nemoclaw my-hermes-local status
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

## Stop

Stop the web app and local vLLM container:

```bash
./stop.sh
```

Keep the model server warm and stop only the web app:

```bash
STOP_MODEL=false ./stop.sh
```

## Restart

Restart everything:

```bash
./restart.sh
```

Restart the web app while keeping an already-running model server warm:

```bash
STOP_MODEL=false ./stop.sh
./start.sh
```

## Script Summary

The root scripts are the day-2 controls:

```bash
./start.sh       # start local vLLM, then start the web app
./stop.sh        # stop the web app and vLLM
./restart.sh     # stop, then start again
```

Useful variants:

```bash
START_WEB=false ./start.sh  # start only local vLLM
STOP_MODEL=false ./stop.sh  # stop only the web app, keep vLLM warm
PORT=8766 ./start.sh        # use a different web port
```

## Health Checks

Check vLLM:

```bash
curl http://localhost:8000/v1/models
```

Check NemoClaw:

```bash
nemoclaw my-hermes-local status
```

Check the web UI:

```bash
curl -I http://localhost:8765/
```

Run a quick chat test through the web server:

```bash
curl -sS -N http://localhost:8765/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Reply exactly SERVER_CHAT_OK","new_session":true}'
```

## Notes

- The repo does not include sample media files. Upload your own video, audio,
  image, or PDF through the web UI.
- The root `start.sh` starts vLLM first, waits for `http://localhost:8000/v1`,
  then starts the browser demo.
- The sandbox is intentionally onboarded with `--no-gpu`; the GPU is used by
  the separate vLLM container, not by the sandbox.
- Hermes requires at least a 64K context window, so the local vLLM server starts
  with `--max-model-len 65536`.
