#!/usr/bin/env python3
"""Render goose_egg.sh from templates and configuration."""

from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import re
import tarfile
import textwrap
from pathlib import Path
from typing import Dict, Iterable, Tuple

PLACEHOLDER_PATTERN = re.compile(r"\{\{\s*([A-Za-z0-9_!]+)\s*\}\}")


def load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def resolve_path(base_dir: Path, config_dir: Path, target: str | Path) -> Path:
    path = Path(target)
    if path.is_absolute():
        return path

    for root in (config_dir, base_dir):
        candidate = (root / path).resolve()
        if candidate.exists():
            return candidate

    return (base_dir / path).resolve()


def deep_merge_dicts(base: Dict, override: Dict) -> Dict:
    result: Dict = {}
    for key, value in base.items():
        result[key] = value
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge_dicts(result[key], value)
        else:
            result[key] = value
    return result


def select_variant(config: dict, requested: str | None) -> tuple[str, dict]:
    variants = config.get("variants")
    if not variants:
        selected_name = requested or "default"
        return selected_name, config

    if requested is None:
        selected_name = next(iter(variants))
    else:
        if requested not in variants:
            raise KeyError(f"Unknown variant '{requested}'. Available: {', '.join(sorted(variants))}")
        selected_name = requested

    base_context = {
        key: value
        for key, value in config.items()
        if key not in {"variants", "egg_schema", "egg_name", "description"}
    }
    variant_config = deep_merge_dicts(base_context, variants[selected_name])
    return selected_name, variant_config


def build_context(
    config: dict,
    variant_config: dict,
    base_dir: Path,
    config_dir: Path,
    variant_name: str,
) -> tuple[dict, set[Path]]:
    required_keys = ("project_root", "module_path", "session_name", "editor_cmd", "model_name")
    missing = [key for key in required_keys if key not in variant_config]
    if missing:
        raise KeyError(f"Variant '{variant_name}' missing required keys: {', '.join(missing)}")

    context = {
        "PROJECT_ROOT": variant_config["project_root"],
        "MODULE_PATH": variant_config["module_path"],
        "SESSION_NAME": variant_config["session_name"],
        "EDITOR_CMD": variant_config["editor_cmd"],
        "MODEL_NAME": variant_config["model_name"],
        "EGG_SCHEMA": config.get("egg_schema", "v1"),
        "EGG_NAME": config.get("egg_name", ""),
        "EGG_DESCRIPTION": config.get("description", ""),
        "VARIANT_NAME": variant_name,
        "VARIANT_TARGET": variant_config.get("target", ""),
        "VARIANT_PROFILE": variant_config.get("profile", ""),
        "VARIANT_PROVIDER": variant_config.get("provider", ""),
    }

    source_paths: set[Path] = set()

    for group in ("docs", "snippets", "values"):
        for key, relative in variant_config.get(group, {}).items():
            resolved = resolve_path(base_dir, config_dir, relative)
            source_paths.add(resolved)
            context[key] = load_text(resolved).rstrip("\n")

    return context, source_paths


def render_template(template_text: str, context: dict) -> str:
    def replace(match: re.Match) -> str:
        key = match.group(1)
        if key.startswith("!"):
            return ""
        if key not in context:
            raise KeyError(f"Missing value for placeholder '{key}'")
        return str(context[key])

    return PLACEHOLDER_PATTERN.sub(replace, template_text)


def write_output(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def payload_key(path: Path, base_dir: Path) -> str:
    try:
        relative = path.relative_to(base_dir)
        relative_str = relative.as_posix()
    except ValueError:
        relative_str = path.name
    return f"egg/{relative_str}"


def format_base64(data: str, width: int = 76) -> str:
    return "\n".join(textwrap.wrap(data, width))


def build_egg_payload(paths: Iterable[Path], base_dir: Path) -> tuple[str, str, dict]:
    unique: Dict[str, Path] = {}
    for path in paths:
        resolved = path.resolve()
        key = payload_key(resolved, base_dir)
        unique[key] = resolved

    manifest: Dict[str, str] = {}
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as tar:
        for key in sorted(unique):
            file_path = unique[key]
            data = file_path.read_bytes()
            info = tarfile.TarInfo(name=key)
            info.size = len(data)
            info.mode = 0o644
            info.mtime = 0
            info.uid = 0
            info.gid = 0
            info.uname = ""
            info.gname = ""
            tar.addfile(info, io.BytesIO(data))
            manifest[key] = hashlib.sha256(data).hexdigest()

    tar_bytes = buffer.getvalue()
    tar_hash = hashlib.sha256(tar_bytes).hexdigest()
    b64 = base64.b64encode(tar_bytes).decode("ascii")
    return format_base64(b64), tar_hash, manifest


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render goose_egg.sh from templates.")
    parser.add_argument(
        "--config",
        default="config/variables.json",
        type=Path,
        help="Path to configuration JSON file.",
    )
    parser.add_argument(
        "--template",
        type=Path,
        help="Override template path (otherwise taken from config).",
    )
    parser.add_argument(
        "--variant",
        type=str,
        help="Variant name to render (defaults to the first configured variant).",
    )
    parser.add_argument(
        "--output",
        default=Path("goose_egg.sh"),
        type=Path,
        help="Output path for rendered script.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config_path = args.config.resolve()
    config = load_config(config_path)
    config_dir = config_path.parent
    base_dir = config_dir.parent

    variant_name, variant_config = select_variant(config, args.variant)

    template_value = args.template or variant_config.get("template")
    if not template_value:
        raise ValueError("Template path must be provided via --template or in the configuration.")

    template_resolved = resolve_path(base_dir, config_dir, template_value)
    template_text = load_text(template_resolved)

    context, source_paths = build_context(config, variant_config, base_dir, config_dir, variant_name)

    payload_paths = set(source_paths)
    payload_paths.add(template_resolved)
    payload_paths.add(config_path)
    payload_b64, payload_sha, manifest = build_egg_payload(payload_paths, base_dir)

    context.update(
        {
            "EGG_PAYLOAD_B64": payload_b64,
            "EGG_PAYLOAD_SHA256": payload_sha,
            "EGG_MANIFEST_JSON": json.dumps(manifest, indent=2, sort_keys=True),
        }
    )

    rendered = render_template(template_text, context)

    write_output(args.output, rendered)


if __name__ == "__main__":
    main()
