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
sudo apt-get update
sudo apt-get install -y ffmpeg poppler-utils lsof python3-venv
```

The start script also expects Docker with NVIDIA GPU container support, which is
included on the DGX Spark software image used for this demo.

Install NemoClaw/OpenShell:

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | \
  bash -s -- --yes-i-accept-third-party-software
```

Make sure the new CLIs are on your path:

```bash
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
```

Download the local Omni model:

```bash
python3 -m venv "$HOME/.local/share/hf-download-venv"
"$HOME/.local/share/hf-download-venv/bin/pip" install -U pip 'huggingface_hub[hf_xet]'
"$HOME/.local/share/hf-download-venv/bin/hf" download \
  nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4 \
  --local-dir "$HOME/models/nemotron-3-nano-omni-nvfp4"
```

If Hugging Face asks for authentication, accept the model terms in your browser
and export a token before running the download:

```bash
export HF_TOKEN="hf_..."
```

Start only the local vLLM model server:

```bash
START_WEB=false ./start.sh
```

Onboard the Hermes sandbox against local vLLM:

```bash
NEMOCLAW_EXPERIMENTAL=1 \
NEMOCLAW_PROVIDER=vllm \
NEMOCLAW_MODEL=nvidia/nemotron-3-nano-omni-30b-a3b-reasoning \
NEMOCLAW_LOCAL_INFERENCE_TIMEOUT=600 \
nemoclaw onboard \
  --non-interactive \
  --fresh \
  --name my-hermes-local \
  --agent hermes \
  --no-gpu \
  --no-sandbox-gpu \
  --yes \
  --yes-i-accept-third-party-software
```

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

For the Spark used during setup, that was:

```text
http://192.168.1.164:8765
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
