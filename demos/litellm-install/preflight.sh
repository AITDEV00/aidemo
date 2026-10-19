#!/usr/bin/env bash
# aidemo preflight hook — run from the demo dir before every take
# (probe / record / render). Each take gets a FRESH container, so the
# recorded flow is always a deterministic first run.
set -euo pipefail

DIR="${AIDEMO_DEMO_DIR:-$(cd "$(dirname "$0")" && pwd)}"
PORT=7681
IMAGE=litellm-install-demo
CONTAINER=litellm-install-demo

mkdir -p "$DIR/logs"

command -v ttyd >/dev/null 2>&1 || {
  echo "preflight: ttyd not found. Install it first:"
  echo "  sudo apt install ttyd        # Ubuntu 24.04+"
  echo "  # or a static binary: https://github.com/tsl0922/ttyd/releases"
  exit 1
}
command -v podman >/dev/null 2>&1 || { echo "preflight: podman not found"; exit 1; }

# Clean up leftovers from a previous take: killing ttyd SIGHUPs the podman
# child and --rm tears the container down; rm -f is the belt to those braces.
pkill -f "ttyd.*-p $PORT" 2>/dev/null || true
podman rm -f "$CONTAINER" >/dev/null 2>&1 || true
sleep 0.3

# Build once; later takes reuse the cached layer.
podman image inspect "$IMAGE" >/dev/null 2>&1 || podman build -t "$IMAGE" "$DIR"

# -W  writable TTY (the take types into the shell)
# -o  one client: ttyd exits when the recording browser disconnects, so the
#     --rm container never outlives the take
# -t rendererType=dom  DOM rows instead of a WebGL canvas — required so the
#     key line is a real element the storyboard `redact` selector can target.
# -t fontSize=20  large, legible terminal text at 1920x1080. At this size the
#     ~66-line install output overflows the 46-row viewport, but the key line
#     stays pinned at row 10 through typing + validation (where the redact
#     blur covers it), then scrolls off in a single jump once the install
#     output lands — so the key is never on screen unblurred.
nohup ttyd -W -o -p "$PORT" -t rendererType=dom -t fontSize=20 -- \
  podman run --rm -it --name "$CONTAINER" "$IMAGE" bash \
  >>"$DIR/logs/ttyd.log" 2>&1 &

# Wait for the page to come up.
for _ in $(seq 1 100); do
  curl -fsS "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && exit 0
  sleep 0.1
done
echo "preflight: ttyd did not come up on port $PORT — see $DIR/logs/ttyd.log"
exit 1
