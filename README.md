# Goose Egg Bootstrap Script

This repo now ships a templated generator for the Goose bootstrap script. `render.py` merges `templates/goose_egg.sh.tmpl` with Markdown/snippet templates and `config/variables.json` to produce `goose_egg.sh`. We keep the original hardboiled artifact in `golden_egg.sh` as a byte-for-byte reference while continuing to evolve the soft egg.

Showcase: the repository at <https://github.com/taituo/goose> was generated with this toolchain, demonstrating the scaffold in a full project context. This repo also ships `goose_egg.sh`—a hardboiled egg example ready to run as-is.

### Foreword
- It began with <https://github.com/taituo/talktomegoose/tree/master>, where the author experimented with an agentic wrapper and personas but paused once similar tools surfaced elsewhere.
- Focus then shifted to a single-shot bootstrapper—Goose—that distilled the workflow into one executable script.
- The effort culminated in this Goose Egg project: a templated system proving the "egg" must exist before every future Goose and enabling new projects to hatch on demand.

### Why “Goose Egg”?
The original bootstrapper existed before the Goose project proper, so the seed script took on the name "goose egg." Now that the Goose workflow is established, the templating engine lets you hatch additional Codex-driven projects from this same egg with minimal changes.

To oneshot a fresh Goose workspace today, you only need:
- a minimal development environment (git, go, tmux);
- an internet connection for ChatGPT/Codex access;
- the `goose_egg.sh` hardboiled egg from this repo.

Run the script once and it recreates the full scaffold deterministically—no wrapper maintenance required.

`goose_egg.sh` (with the historical version preserved at `golden_egg.sh`) is a one-shot bootstrapper that sets up the Goose development environment: it initializes a Go module, scaffolds the documentation/spec files, prepares task and handoff directories, and optionally launches Codex to begin the next development increment.

## Prerequisites
- `git`
- `go`
- `tmux`
- Optional: `codex` CLI for AI-assisted panes

Ensure those binaries are on your `PATH` before running the script.

## Rendering
Regenerate `goose_egg.sh` at any time. Variants live inside `config/variables.json`; omit `--variant` to use the first entry:

```bash
python3 render.py --variant go-minimal --output goose_egg.sh
```

By default the renderer reads `config/variables.json` for high-level settings and relative paths to the Markdown/snippet templates housed in `templates/`. Edit those files to change defaults, tweak document content, or point at new templates. The renderer now bundles the referenced files into a deterministic tarball, records its SHA256, and injects the payload into the oneshot for verification or extraction.

The templating engine is intentionally modular—drop in new template sets for other Codex projects (service stubs, docs-only setups, etc.) and reference them from the config to reuse the rendering pipeline.

### Vibe Coding > Refactoring
For small, fast-moving tools, vibe coding—blueprinting the experience and generating from templates—beats continual refactoring. Once the egg (templates + config) is in place, you rebuild cleanly instead of wrestling with incremental rewrites. Refactoring has its place, but codex-driven blueprints keep momentum high and drift low.

## Tests
Verify the renderer output stays byte-identical with the original script and that egg verification/extraction still work. Pytest exercises the Python renderer utilities alongside the shell smoke test:

```bash
./tests/test_render_matches_final.sh
# or simply
make test  # runs shell smoke + pytest suite inside .venv
```

The shell test also pins the `golden_egg.sh` checksum to guarantee we never modify the hardboiled reference.

```bash
make venv   # optional: pre-create the virtualenv for reuse
make clean  # remove goose_egg.sh and the local .venv when done
```

## TODO (template expansion ideas)
- Add template bundles for other Codex project types (e.g., REST API starter, docs-only portal, CLI utilities).
- Parameterize task and handoff templates so multiple tasks can be seeded from configuration.
- Introduce optional testing scaffolds (Go test, lint) toggled via config flags.

## Usage
Run the rendered script from any directory:

```bash
./goose_egg.sh
```

The script creates (or reuses) the repo at `/root/dev/talktomegoose_reboot`, initializes the `dev` branch, and writes documentation/task files only if they are missing. Existing files are left untouched.

### Runtime Flags
- `--exec` – launch Codex in non-interactive exec mode after bootstrapping.
- `--kill-codex-first` – retained for compatibility; prints a reminder but performs no action.
- `--skip-codex` – skip launching Codex entirely.
- `--verify-egg` – validate the embedded egg manifest and exit.
- `--extract-egg[=DIR]` – recover the egg payload (defaults to `./egg_payload`) and exit. Extraction always verifies before writing the files.

### Egg Introspection
```bash
# prove integrity without creating files
./goose_egg.sh --verify-egg

# extract the egg (config + templates) used to build the oneshot
./goose_egg.sh --extract-egg=./egg_payload
```

The extracted tree mirrors the source `config/` and `templates/` inputs, so you can audit or regenerate the egg in a fresh workspace.

### Updating GitHub
All docs (`SPEC.md`, `CLI.md`, `ROLE.md`, `OPERATIONS.md`, `README.md`, tasks/handoffs) are rendered from the egg. Before pushing updates to GitHub, rerun `python3 render.py` (or `make render`) so the oneshot and generated docs stay in sync, then commit the refreshed outputs together.

### Customizing Defaults
Edit `config/variables.json` to change the repo path, Go module path, tmux session name, preferred editor, or model name. Re-render afterwards so the generated script picks up the new defaults.

## What Gets Created
- Go stub (`main.go`) and `go.mod`
- Docs: `SPEC.md`, `CLI.md`, `ROLE.md`, `OPERATIONS.md`, `README.md`
- Tasks and handoff files under `tasks/` and `handoffs/`
- `.gitignore`

All files are written with `write_if_absent`, so rerunning the script is safe.

## Packaging
After running the script, build the Goose binary for distribution:

```bash
go build -o goose /root/dev/talktomegoose_reboot
```

To share the scaffolded state without the repo history, create an archive:

```bash
cd /root/dev/talktomegoose_reboot
zip -r goose_skeleton.zip . -x '.git/*'
```

The archive contains the generated docs, handoff templates, and Go stub, ready for collaborators to pick up.

## Future Work
- `FUTURE.md` outlines how soft eggs graduate into hard eggs and enumerates prospective one-shot multi-agent microservice variants.
