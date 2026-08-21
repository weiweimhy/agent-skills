#!/usr/bin/env python3
"""Run the bundled ImageGen CLI with relay settings from Codex config files."""

import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any

try:
    import tomllib
except ImportError:
    import tomli as tomllib


def _as_dict(value: object) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _first(mapping: object, *keys: str) -> str | None:
    values = _as_dict(mapping)
    for key in keys:
        value = values.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _settings(home: Path) -> tuple[str, str, str, str]:
    config_path = home / "config.toml"
    auth_path = home / "auth.json"
    config: dict[str, Any] = {}
    auth: dict[str, Any] = {}

    if config_path.exists():
        with config_path.open("rb") as handle:
            config = tomllib.load(handle)
    if auth_path.exists():
        with auth_path.open(encoding="utf-8") as handle:
            auth = _as_dict(json.load(handle))

    provider_name = config.get("model_provider")
    providers = _as_dict(config.get("model_providers"))
    provider = _as_dict(providers.get(provider_name))
    shell_policy = _as_dict(config.get("shell_environment_policy"))
    shell_env = _as_dict(shell_policy.get("set"))

    base_url = (
        _first(provider, "base_url", "openai_base_url")
        or _first(config, "OPENAI_BASE_URL", "openai_base_url", "base_url")
        or _first(shell_env, "OPENAI_BASE_URL")
    )
    api_key = _first(
        provider, "experimental_bearer_token", "api_key"
    ) or _first(shell_env, "OPENAI_API_KEY")
    base_source = "config.toml" if base_url else None
    key_source = "config.toml" if api_key else None

    if not base_url:
        base_url = _first(auth, "OPENAI_BASE_URL", "base_url")
        base_source = "auth.json" if base_url else None
    if not api_key:
        api_key = _first(auth, "OPENAI_API_KEY", "api_key", "access_token")
        if not api_key:
            api_key = _first(auth.get("tokens"), "access_token")
        key_source = "auth.json" if api_key else None

    missing = [
        name
        for name, value in (("relay base URL", base_url), ("relay token", api_key))
        if not value
    ]
    if missing:
        raise SystemExit(
            "Missing " + " and ".join(missing) + f" in {config_path} and {auth_path}"
        )

    assert base_url is not None
    assert api_key is not None
    assert base_source is not None
    assert key_source is not None
    return base_url, api_key, base_source, key_source


def main() -> int:
    home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")).expanduser()
    base_url, api_key, base_source, key_source = _settings(home)

    if sys.argv[1:] == ["--check"]:
        print(f"Relay configuration OK (base URL: {base_source}; token: {key_source})")
        return 0
    if not sys.argv[1:]:
        raise SystemExit("Usage: relay_imagegen.py <generate|edit|generate-batch> [options]")

    image_gen = home / "skills" / ".system" / "imagegen" / "scripts" / "image_gen.py"
    if not image_gen.is_file():
        raise SystemExit(f"Bundled ImageGen CLI not found: {image_gen}")

    env = os.environ.copy()
    env["OPENAI_BASE_URL"] = base_url
    env["OPENAI_API_KEY"] = api_key
    return subprocess.run(
        [sys.executable, str(image_gen), *sys.argv[1:]], env=env, check=False
    ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
