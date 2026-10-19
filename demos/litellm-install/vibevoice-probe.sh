#!/usr/bin/env bash
# Probe gateway VibeVoice-ASR (chat-completions shaped, per
# oicm-litellm-layer/docs/usage-guides/VIBEVOICE_ASR_GUIDE.md) with the
# engine's actual narration.mp3. Prints measured segment timestamps to
# compare against voice.json scene boundaries.
set -euo pipefail
# Gateway key: export GATEWAY_KEY=sk-... before running (never commit a real key).
KEY="${GATEWAY_KEY:-sk-REPLACE-ME}"
URL="https://litellm.ecouncil.ae/v1/chat/completions"
NARR="$(cd "$(dirname "$0")" && pwd)/audio/narration.mp3"

# 16 kHz mono WAV — standard ASR input, ~1/3 the payload of 44.1 kHz stereo.
timeout 30 ffmpeg -hide_banner -loglevel error -y -i "$NARR" \
  -ar 16000 -ac 1 -c:a pcm_s16le /tmp/narration16k.wav
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/narration16k.wav)
echo "wav duration: ${DUR}s  size: $(stat -c%s /tmp/narration16k.wav) bytes"

python3 - "$DUR" <<'EOF'
import base64, json, sys
dur = float(sys.argv[1])
b64 = base64.b64encode(open("/tmp/narration16k.wav", "rb").read()).decode()
payload = {
    "model": "microsoft/VibeVoice-ASR",
    "messages": [
        {"role": "system", "content": "You are a helpful assistant that transcribes audio input into text output in JSON format."},
        {"role": "user", "content": [
            {"type": "text", "text": f"This is a {dur:.1f} seconds audio, please transcribe it with these keys: Start time, End time, Speaker ID, Content"},
            {"type": "input_audio", "input_audio": {"data": b64, "format": "wav"}},
        ]},
    ],
    "temperature": 0.0,
    "repetition_penalty": 1.05,
    "max_tokens": 1500,
}
open("/tmp/vv-req.json", "w").write(json.dumps(payload))
print(f"payload: {len(json.dumps(payload)) / 1e6:.1f} MB")
EOF

T0=$(date +%s.%N)
code=$(curl -sk --max-time 180 "$URL" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/vv-req.json -o /tmp/vv-resp.json -w "%{http_code}")
T1=$(date +%s.%N)
echo "HTTP $code in $(echo "$T1 - $T0" | bc)s"

python3 - <<'EOF'
import json
r = json.load(open("/tmp/vv-resp.json"))
if "choices" not in r:
    print("ERROR:", json.dumps(r)[:400])
    raise SystemExit(1)
ch = r["choices"][0]
print("finish_reason:", ch["finish_reason"])
content = ch["message"]["content"].strip()
if content.startswith("assistant"):
    content = content[len("assistant"):].strip()
segs = json.loads(content)
print(f"{len(segs)} segment(s):")
for s in segs:
    print(f"  [{float(s['Start']):6.2f} -> {float(s['End']):6.2f}] spk{s['Speaker']}: {s['Content']}")
EOF
