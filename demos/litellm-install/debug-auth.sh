#!/usr/bin/env bash
set -euo pipefail
# Gateway key: export GATEWAY_KEY=sk-... before running (never commit a real key).
KEY="${GATEWAY_KEY:-sk-REPLACE-ME}"
echo "=== all model ids ==="
python3 - <<'EOF'
import json
data = json.load(open('/tmp/models.json'))
for m in data['data']:
    print(m['id'])
EOF

echo
echo "=== TTS smoke test: POST /v1/audio/speech (hamsa-tts) ==="
curl -sS --max-time 90 -X POST "https://litellm.ecouncil.ae/v1/audio/speech" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"hamsa-tts","input":"Testing gateway voiceover, one two three.","voice":"default"}' \
  -o /tmp/tts-test2.mp3 -w "HTTP %{http_code}\n"
file /tmp/tts-test2.mp3 2>/dev/null || head -c 300 /tmp/tts-test2.mp3
echo
echo "=== STT smoke test: POST /v1/audio/transcriptions (hamsa-stt) ==="
curl -sS --max-time 60 -X POST "https://litellm.ecouncil.ae/v1/audio/transcriptions" \
  -H "Authorization: Bearer $KEY" \
  -F "model=hamsa-stt" -F "file=@/tmp/tts-test.mp3" \
  -w "\nHTTP %{http_code}\n" | head -c 500
