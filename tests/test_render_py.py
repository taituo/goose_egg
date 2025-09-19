import base64
import hashlib
import io
import os
import importlib.util
import subprocess
import sys
import tarfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
RENDER_PATH = REPO_ROOT / "render.py"

spec = importlib.util.spec_from_file_location("render_module", RENDER_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("Unable to load render.py for testing")
render = importlib.util.module_from_spec(spec)
spec.loader.exec_module(render)


def _run_render(output_path: Path) -> None:
    subprocess.run(
        [sys.executable, "render.py", "--variant", "go-minimal", "--output", str(output_path)],
        cwd=REPO_ROOT,
        check=True,
    )


def _decode_payload(payload_b64: str) -> bytes:
    cleaned = payload_b64.replace("\n", "")
    return base64.b64decode(cleaned.encode("ascii"))


def test_build_egg_payload_manifest_integrity(tmp_path: Path) -> None:
    file_one = tmp_path / "a.txt"
    file_one.write_text("alpha", encoding="utf-8")

    nested_dir = tmp_path / "nested"
    nested_dir.mkdir()
    file_two = nested_dir / "b.txt"
    file_two.write_text("beta", encoding="utf-8")

    payload_b64, tar_sha, manifest = render.build_egg_payload(
        [file_one, file_two],
        tmp_path,
    )

    payload_bytes = _decode_payload(payload_b64)
    assert hashlib.sha256(payload_bytes).hexdigest() == tar_sha

    with tarfile.open(fileobj=io.BytesIO(payload_bytes), mode="r:gz") as archive:
        member_names = sorted(member.name for member in archive.getmembers() if member.isfile())
        assert member_names == sorted(manifest.keys())
        for member in archive.getmembers():
            if not member.isfile():
                continue
            with archive.extractfile(member) as handle:
                assert handle is not None
                data = handle.read()
            assert hashlib.sha256(data).hexdigest() == manifest[member.name]


def test_render_outputs_metadata(tmp_path: Path) -> None:
    output_script = tmp_path / "goose_egg.sh"
    _run_render(output_script)
    script_text = output_script.read_text(encoding="utf-8")
    assert 'EGG_NAME="goose-egg"' in script_text
    assert "--verify-egg" in script_text
    assert "EGG_PAYLOAD_SHA256" in script_text


def test_rendered_script_verifies_and_extracts(tmp_path: Path) -> None:
    output_script = tmp_path / "goose_egg.sh"
    _run_render(output_script)

    env = os.environ.copy()
    # Ensure python3 finds stdlib even if PYTHONPATH altered by caller.
    env.setdefault("PYTHONPATH", "")

    subprocess.run([str(output_script), "--verify-egg"], cwd=tmp_path, env=env, check=True)

    extract_dir = tmp_path / "egg_payload"
    subprocess.run(
        [str(output_script), f"--extract-egg={extract_dir}"],
        cwd=tmp_path,
        env=env,
        check=True,
    )
    config_path = extract_dir / "egg" / "config" / "variables.json"
    assert config_path.exists()
