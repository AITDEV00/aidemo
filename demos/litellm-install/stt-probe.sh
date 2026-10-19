#!/usr/bin/env bash
# Probe gateway STT models with the exact request shape src/captions.ts sends:
# multipart file= (the MP3 the engine produces), response_format=verbose_json,
# timestamp_granularities=["word"]. A usable model returns {words:[{word,start,end}]}.
set -u
# Gateway key: export GATEWAY_KEY=sk-... before running (never commit a real key).
KEY="${GATEWAY_KEY:-sk-REPLACE-ME}"
URL="https://litellm.ecouncil.ae/v1/audio/transcriptions"

# Need a real speech MP3: use the inception-tts sample from tts-probe.sh
if [ ! -s /tmp/tts-inception-tts.mp3 ] || grep -q "JSON text" <(file -b /tmp/tts-inception-tts.mp3); then
  curl -sS --max-time 90 -X POST "https://litellm.ecouncil.ae/v1/audio/speech" \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d '{"model":"inception-tts","input":"Testing voiceover, one two three.","voice":"default"}' \
    -o /tmp/tts-inception-tts.mp3
fi
echo "sample: $(file -b /tmp/tts-inception-tts.mp3)"

for model in inception-stt "Qwen/Qwen3-ASR-1.7B" "microsoft/VibeVoice-ASR" hamsa-stt; do
  code=$(curl -sS --max-time 120 -X POST "$URL" \
    -H "Authorization: Bearer $KEY" \
    -F "model=$model" \
    -F "file=@/tmp/tts-inception-tts.mp3;type=audio/mpeg" \
    -F "response_format=verbose_json" \
    -F 'timestamp_granularities[]=["word"]' \
    -o "/tmp/stt-$(basename "$model").json" -w "%{http_code}")
  echo "--- $model -> HTTP $code"
  head -c 260 "/tmp/stt-$(basename "$model").json"; echo; echo
done
