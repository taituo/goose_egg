#!/usr/bin/env python3
"""Render goose_egg.sh from templates and configuration."""

import argparse
import json
import re
from pathlib import Path

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


def build_context(config: dict, base_dir: Path, config_dir: Path) -> dict:
    context = {
        "PROJECT_ROOT": config["project_root"],
        "MODULE_PATH": config["module_path"],
        "SESSION_NAME": config["session_name"],
        "EDITOR_CMD": config["editor_cmd"],
        "MODEL_NAME": config["model_name"],
    }

    for group in ("docs", "snippets", "values"):
        for key, relative in config.get(group, {}).items():
            resolved = resolve_path(base_dir, config_dir, relative)
            context[key] = load_text(resolved).rstrip("\n")

    return context


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
        "--output",
        default=Path("goose_egg.sh"),
        type=Path,
        help="Output path for rendered script.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    config_dir = args.config.parent.resolve()
    base_dir = config_dir.parent.resolve()

    template_path = args.template or config.get("template")
    if not template_path:
        raise ValueError("Template path must be provided via --template or config['template']")

    template_resolved = resolve_path(base_dir, config_dir, template_path)
    template_text = load_text(template_resolved)

    context = build_context(config, base_dir, config_dir)
    rendered = render_template(template_text, context)

    write_output(args.output, rendered)


if __name__ == "__main__":
    main()
