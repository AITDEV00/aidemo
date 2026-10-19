#!/usr/bin/env bash
# Probe each gateway TTS model with the OpenAI audio/speech shape the engine
# sends. Prints model -> HTTP status + audio format for the winners.
set -u
# Gateway key: export GATEWAY_KEY=sk-... before running (never commit a real key).
KEY="${GATEWAY_KEY:-sk-REPLACE-ME}"
URL="https://litellm.ecouncil.ae/v1/audio/speech"

for model in hamsa-tts-new inception-tts omnivoice; do
  for voice in default alloy 1 en-US-Neural2-A; do
    code=$(curl -sS --max-time 90 -X POST "$URL" \
      -H "Authorization: Bearer $KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$model\",\"input\":\"Testing voiceover, one two three.\",\"voice\":\"$voice\"}" \
      -o "/tmp/tts-$model.mp3" -w "%{http_code}")
    kind=$(file -b "/tmp/tts-$model.mp3" 2>/dev/null | head -c 40)
    echo "$model voice=$voice -> HTTP $code ($kind)"
    if [ "$code" = "200" ] && ! grep -q "JSON text" <<<"$kind"; then
      break
    fi
  done
done

echo
echo "=== error bodies (first failure per model) ==="
for model in hamsa-tts-new inception-tts omnivoice; do
  echo "--- $model ---"
  head -c 300 "/tmp/tts-$model.mp3"; echo
done
