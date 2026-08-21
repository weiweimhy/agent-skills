---
name: relay-imagegen
description: Generate or edit images through the OpenAI-compatible relay configured in Codex config/auth files. Use when the user explicitly asks for relay, proxy, custom-endpoint, or "中转站" image generation instead of the built-in image tool.
---

# Relay ImageGen

Use `scripts/relay_imagegen.py` from this skill directory to run the bundled
system ImageGen CLI through the user's configured relay. Do not use the
built-in image generation tool when the request explicitly requires a relay.

Resolve the wrapper path relative to this loaded `SKILL.md`; do not assume the
skill is installed under `CODEX_HOME`.

The wrapper resolves credentials at runtime in this order:

1. Read the active model provider from `${CODEX_HOME:-~/.codex}/config.toml`.
2. Read missing values from `${CODEX_HOME:-~/.codex}/auth.json`.
3. Fail without making a request if either the base URL or token is missing.

Accept both `base_url` and `openai_base_url` in Codex config, including
top-level values and active `model_providers` entries. If `--check` reports a
missing base URL while `config.toml` contains `openai_base_url`, verify the
wrapper's field resolution instead of asking the user to paste credentials.

Never print, copy, persist, or ask the user to paste resolved credentials.

## Run

Use `uv` so no permanent Python package installation is required. Replace
`<skill-directory>` with the directory containing this `SKILL.md`.

Before the first live request, verify credential resolution without revealing
the resolved values:

```bash
uv run --with tomli python \
  "<skill-directory>/scripts/relay_imagegen.py" \
  --check
```

Generate an image with:

```bash
uv run --with openai --with tomli python \
  "<skill-directory>/scripts/relay_imagegen.py" \
  generate \
  --prompt "<prompt>" \
  --out "<workspace-output-path>"
```

Pass normal system ImageGen CLI arguments after the wrapper path. The default
model is `gpt-image-2`; select another `gpt-image-*` model only when the user
requests it or the relay requires it.

For edits, use the `edit` subcommand and pass `--image`. For multiple distinct
prompts, use `generate-batch`.

## Transparent Image Workflow

Do not assume a relay supports direct transparent output, even when the
upstream CLI exposes `--background transparent`. Some relay/model combinations
reject transparent backgrounds or render a checkerboard into the image.

For sticker-like transparent assets:

1. Generate or edit an opaque PNG with the subject isolated on a plain white
   or solid-color background suitable for background removal. Do not request a
   checkerboard background.
2. Run a local background-removal or cutout step to convert the result to RGBA.
   Edge-connected solid-background removal is sufficient for simple assets;
   use a stronger matting tool for complex hair, fur, edges, or shadows.
3. Visually inspect the result and verify its alpha channel.

After generation, inspect the image, save project assets inside the workspace,
and report the output path and final prompt. If network access is blocked,
request the narrow approval needed to rerun the same command.
