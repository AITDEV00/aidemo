# litellm-install — demo video for the gateway `/install` flow

Records the **real** install script (`curl -fsSL <gateway>/install | bash`)
running in a **real shell**, via [ttyd](https://github.com/tsl0922/ttyd)
(PTY → xterm.js in the browser) wrapping a podman container. Every take gets
a fresh container through the storyboard's `setup.preflight` hook, so the
recorded flow is a deterministic first run.

What the video shows (the three features from the litellm PR):
1. Prompts print the label first, input goes on its own `>` line.
2. The key prompt is readline-backed — the storyboard presses ArrowLeft/
   ArrowRight mid-key to prove arrows edit instead of injecting `^[[D`.
3. Only installed harnesses are offered (container pre-creates `~/.gemini`
   and `~/.config/opencode`, so the menu shows exactly `1) gemini 2) open-code`),
   then OpenCode is configured via cc-switch.

## Layout

- `Containerfile` — the "dev machine": ubuntu + curl, with gemini/opencode
  config dirs pre-created so the detection has something to find.
- `preflight.sh` — pre-take hook: kills the last ttyd/container, (re)builds
  the image if missing, starts `ttyd -W -o` → `podman run --rm -it`, waits
  for the page.
- `storyboard.json` — 4 scenes, ~50 s target.

## Prereqs (one-time, in WSL)

```sh
sudo apt install -y ttyd            # or static binary from ttyd releases
# engine prereqs (repo root):
cd "$(git rev-parse --show-toplevel)" && npm install   # Node 20+, ffmpeg, Chrome also needed
```

Voice: `OPENAI_API_KEY` in `aidemo/.env`, or fully offline with
`AIDEMO_TTS_PROVIDER=local` (+ `npm install kokoro-js`).

## Gateway key — read before publishing

`params.apiKey` is the gateway key typed **on camera and into a real PTY**. The
committed default is a placeholder (`sk-REPLACE-ME`); supply a real key per run:

```sh
# mint a fresh "burner" virtual key on the gateway, then:
node bin/aidemo.mjs render demos/litellm-install --headless \
  --param apiKey=sk-the-fresh-burner
# revoke the burner on the gateway AFTER recording, BEFORE sharing the MP4
```

The key line is blurred post-hoc. `preflight.sh` starts ttyd with
`-t rendererType=dom` (xterm.js renders real DOM rows, not a canvas) and the
storyboard's `redact` selector blurs the key's text row. Never write a real key
into a tracked file — keep it out of `storyboard.json` / `generated/params.json`
(gitleaks runs in CI). Use `--param apiKey=...` or an env var instead.

## Run

```sh
cd "$(git rev-parse --show-toplevel)"
node bin/aidemo.mjs validate demos/litellm-install   # schema check, no browser
node bin/aidemo.mjs lint    demos/litellm-install     # pacing forecast
node bin/aidemo.mjs probe  demos/litellm-install --headless   # dry-run take
node bin/aidemo.mjs render demos/litellm-install --headless   # full pipeline
node bin/aidemo.mjs frames  demos/litellm-install --every 3   # review frames
```

The preflight hook fires automatically on probe/record/render — you never
start ttyd or podman by hand. Iterate on pacing with `output/report.json`
(measured per-scene timing) and adjust the `pause` values.

## Troubleshooting

- **Slow cc-switch download** (s3's 12 s pause ends before the success
  message): `autoIdle` trims the static part when fast; when slow, re-record
  just the tail — `node bin/aidemo.mjs record demos/litellm-install
  --from-scene s3-menu` — earlier scenes reuse the take's footage.
- **Which xterm renderer?** `preflight.sh` forces `-t rendererType=dom` so the
  terminal is real DOM rows (`.xterm-rows` divs). That is **required** for the
  selector-based `redact` blur of the key line — the default WebGL renderer is a
  single canvas with no per-line elements. It also makes text-based
  `waitForChange`/`assert` possible.
- **Key row vs font size.** The blur targets the key's text row
  (`.xterm-rows > div:nth-child(10)`), stable at `-t fontSize=20` on a 1920x1080
  viewport. If you change the font size, re-check the row — the key prompt moves
  and the `redact` selector must match its new row.
- **Port 7681 busy**: preflight only kills its own ttyd; check
  `logs/ttyd.log` if the page never comes up.
- **"none installed" variant**: build a second image without the `RUN mkdir`
  line and render with a param-swapped storyboard to show the clear error
  path.
