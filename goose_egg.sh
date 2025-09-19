#!/usr/bin/env bash
# Codex best practice: keep bootstrap steps idempotent and tmux-friendly.
set -euo pipefail

# goose-egg.sh — bootstrap everything without breaking Markdown fences.

# -----------------------------
# Hardcoded settings (edit if needed)
# -----------------------------
PROJECT_ROOT="/root/dev/talktomegoose_reboot"
MODULE_PATH="github.com/tuotai/talktomegoose_reboot"
SESSION_NAME="flight"
EDITOR_CMD="nvim"
MODEL_NAME="gpt-5"

# -----------------------------
# Egg metadata (for verification & extraction)
# -----------------------------
EGG_NAME="goose-egg"
EGG_SCHEMA="v1"
EGG_DESCRIPTION="Soft egg for the Goose tmux multi-agent bootstrapper."
VARIANT_NAME="go-minimal"
VARIANT_TARGET="go"
VARIANT_PROFILE="minimal"
VARIANT_PROVIDER="openai"
EGG_PAYLOAD_SHA256="80186528f5b293989fd539f3b571a01536907725986ecd1d9948101e2a6ac1a2"

# -----------------------------
# Runtime flags (defaults)
#   --exec              -> Codex non-interactive one-shot
#   --kill-codex-first  -> (no-op) preserved for compatibility; prints a note
#   --skip-codex        -> skip Codex stage entirely
# -----------------------------
CODEX_MODE="interactive"   # or "exec"
KILL_CODEX_FIRST="no"
SKIP_CODEX="no"
VERIFY_EGG="no"
EXTRACT_EGG_DEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --exec)
      CODEX_MODE="exec"
      shift
      ;;
    --kill-codex-first)
      KILL_CODEX_FIRST="yes"
      shift
      ;;
    --skip-codex)
      SKIP_CODEX="yes"
      shift
      ;;
    --verify-egg)
      VERIFY_EGG="yes"
      shift
      ;;
    --extract-egg)
      EXTRACT_EGG_DEST="egg_payload"
      shift
      if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        EXTRACT_EGG_DEST="$1"
        shift
      fi
      ;;
    --extract-egg=*)
      EXTRACT_EGG_DEST="${1#--extract-egg=}"
      shift
      ;;
    --help)
      cat <<'EO_HELP'
Usage: ./goose_egg.sh [flags]

  --exec               Run Codex in exec (one-shot) mode after scaffolding.
  --kill-codex-first   Preserve compatibility; prints reminder only.
  --skip-codex         Skip launching Codex entirely.
  --verify-egg         Verify embedded egg manifest and exit.
  --extract-egg[=DIR]  Recover the egg payload into DIR (default: ./egg_payload) and exit.
EO_HELP
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Supported: --exec | --kill-codex-first | --skip-codex | --verify-egg | --extract-egg[=DIR]" >&2
      exit 1
      ;;
  esac
done

# -----------------------------
# Helpers
# -----------------------------
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
have() { command -v "$1" >/dev/null 2>&1; }

# Usage:
# write_if_absent "path/to/file" <<'EOF'
# ...contents...
# EOF
write_if_absent() {
  local path="$1"
  if [ -f "$path" ]; then
    echo "[i] Exists, not overwriting: $path"
  else
    mkdir -p "$(dirname "$path")"
    # shellcheck disable=SC2094
    cat > "$path"
    echo "[i] Created: $path"
  fi
}

commit_if_changes() {
  if ! git diff --quiet --cached || ! git diff --quiet; then
    git add -A
    if ! git diff --cached --quiet; then
      git commit -m "$1"
      echo "[i] Commit done: $1"
    else
      echo "[i] Nothing to commit."
    fi
  else
    echo "[i] No changes."
  fi
}

TODAY="$(date +%F)"

read_egg_payload() {
  cat <<'EO_EGG_PAYLOAD'
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
EO_EGG_PAYLOAD
}

read_egg_manifest() {
  cat <<'EO_EGG_MANIFEST'
{
  "egg/config/variables.json": "625a6dd9abd2987000e44d0face98b3d5bb0bad9cb5188a5439290d670a65134",
  "egg/templates/docs/CLI.md.tmpl": "ec34f3bbfab1afa0bd7916026d4ab6349cd23f97840a2ab6e58105398d971387",
  "egg/templates/docs/OPERATIONS.md.tmpl": "1aa0d734a279fa676b8c1d15c5956e99af86bf4f12ff46f1fa338822c7c19f3f",
  "egg/templates/docs/README.md.tmpl": "848fde054c38e9f19abce0e55ab72c73cf94337505925c29b27bfb5086d68644",
  "egg/templates/docs/ROLE.md.tmpl": "78dd895f93295409092f28e756ab3cbb98a7fa033bf8ea4912e1ba91b6a52fe9",
  "egg/templates/docs/SPEC.md.tmpl": "52b32291c1250518f3d556f54d6e6961a48b0bfa3babf4e00e70e20a9a31a1c6",
  "egg/templates/goose_egg.sh.tmpl": "ff5de0ecef78d31a5bc27447c53e8c4658bfb6d02e5195d7fb9b6db63f3bd176",
  "egg/templates/snippets/gitignore.tmpl": "efa5519d9ee9976a8828802b73c9c820aa36b92997abdade36ba5370dd60e1d5",
  "egg/templates/snippets/handoffs/inbox.md.tmpl": "033992cdfbbcb146421b5004e7fee31a717f4417659163c68f6af8742850d400",
  "egg/templates/snippets/handoffs/outbox/GOOSE.md.tmpl": "7f968c72217aa868c9d50598a115602bda426a60cd4ec8e78bf2ba6a68fc093d",
  "egg/templates/snippets/handoffs/outbox/MAVERICK.md.tmpl": "31fb9c272a84f0d3dc93ac13e443eba9b2e5f33d92a7f583575cd9210a58d424",
  "egg/templates/snippets/main.go.tmpl": "1e249a00a7b64fabb05e91da91f687211450f1c335450bb3503a27857577d487",
  "egg/templates/snippets/tasks/TASK-001-login-api.md.tmpl": "0fd276f5b15513c3109f1d19fc85c901a0caaa00a08f3eaa8796933f893b62c0"
}
EO_EGG_MANIFEST
}

ensure_python() {
  if ! have python3; then
    echo "[e] python3 is required for egg verification and extraction." >&2
    exit 1
  fi
}

run_egg_tool() {
  ensure_python
  local mode="$1"
  local destination="${2:-.}"
  local payload_file manifest_file
  payload_file="$(mktemp)"
  manifest_file="$(mktemp)"
  read_egg_payload >"$payload_file"
  read_egg_manifest >"$manifest_file"
  python3 - "$mode" "$payload_file" "$manifest_file" "$EGG_PAYLOAD_SHA256" "$destination" <<'PY'
import base64
import hashlib
import io
import json
import sys
import tarfile
from pathlib import Path

mode, payload_path, manifest_path, expected_sha, destination = sys.argv[1:6]

with open(payload_path, "r", encoding="utf-8") as handle:
    payload_bytes = base64.b64decode(handle.read().encode())

payload_hash = hashlib.sha256(payload_bytes).hexdigest()
if payload_hash != expected_sha:
    print("[e] Egg payload SHA mismatch", file=sys.stderr)
    sys.exit(1)

with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

buffer = io.BytesIO(payload_bytes)
with tarfile.open(fileobj=buffer, mode="r:gz") as archive:
    members = {member.name: member for member in archive.getmembers() if member.isfile()}
    manifest_names = set(manifest.keys())
    member_names = set(members.keys())

    extra_members = sorted(member_names - manifest_names)
    missing_members = sorted(manifest_names - member_names)

    if extra_members:
        print(f"[e] Payload contains files missing in manifest: {', '.join(extra_members)}", file=sys.stderr)
        sys.exit(1)
    if missing_members:
        print(f"[e] Manifest references missing files: {', '.join(missing_members)}", file=sys.stderr)
        sys.exit(1)

    for name, member in members.items():
        path_parts = Path(name).parts
        if name.startswith("/") or ".." in path_parts:
            print(f"[e] Unsafe path in payload: {name}", file=sys.stderr)
            sys.exit(1)
        extracted = archive.extractfile(member)
        if extracted is None:
            print(f"[e] Unable to read payload member: {name}", file=sys.stderr)
            sys.exit(1)
        try:
            data = extracted.read()
        finally:
            extracted.close()
        digest = hashlib.sha256(data).hexdigest()
        expected = manifest[name]
        if digest != expected:
            print(f"[e] Checksum mismatch for {name}", file=sys.stderr)
            sys.exit(1)

if mode == "verify":
    sys.exit(0)

destination_path = Path(destination)
destination_path.mkdir(parents=True, exist_ok=True)
destination_root = destination_path.resolve()

buffer = io.BytesIO(payload_bytes)
with tarfile.open(fileobj=buffer, mode="r:gz") as archive:
    for member in archive.getmembers():
        target = destination_path / member.name
        target_resolved = target.resolve()
        if not target_resolved.is_relative_to(destination_root):
            print(f"[e] Unsafe extraction target for {member.name}", file=sys.stderr)
            sys.exit(1)
        if member.isdir():
            target.mkdir(parents=True, exist_ok=True)
        elif member.isfile():
            target.parent.mkdir(parents=True, exist_ok=True)
            extracted = archive.extractfile(member)
            if extracted is None:
                print(f"[e] Unable to read payload member: {member.name}", file=sys.stderr)
                sys.exit(1)
            try:
                data = extracted.read()
            finally:
                extracted.close()
            with open(target, "wb") as handle:
                handle.write(data)
        else:
            print(f"[e] Unsupported tar entry type for {member.name}", file=sys.stderr)
            sys.exit(1)
PY
  local status=$?
  rm -f "$payload_file" "$manifest_file"
  return $status
}

verify_egg_payload() {
  if run_egg_tool verify "."; then
    echo "[i] Egg payload verified (${EGG_NAME:-unknown} :: ${VARIANT_NAME:-default})."
  else
    echo "[e] Egg verification failed." >&2
    return 1
  fi
}

extract_egg() {
  local destination="$1"
  if run_egg_tool extract "$destination"; then
    echo "[i] Egg verified (${EGG_NAME:-unknown} :: ${VARIANT_NAME:-default}) and extracted to $destination"
  else
    echo "[e] Failed to extract egg to $destination" >&2
    return 1
  fi
}

if [ -n "$EXTRACT_EGG_DEST" ]; then
  extract_egg "$EXTRACT_EGG_DEST" || exit 1
  exit 0
fi

if [ "$VERIFY_EGG" = "yes" ]; then
  verify_egg_payload || exit 1
  exit 0
fi

echo "[i] Egg: ${EGG_NAME:-unknown} (schema ${EGG_SCHEMA:-v1}, variant ${VARIANT_NAME:-default})"
if [ -n "${VARIANT_TARGET}${VARIANT_PROFILE}${VARIANT_PROVIDER}" ]; then
  echo "[i] Variant target=${VARIANT_TARGET:-n/a} profile=${VARIANT_PROFILE:-n/a} provider=${VARIANT_PROVIDER:-n/a}"
fi

# -----------------------------
# Dependencies
# -----------------------------
need git
need go
need tmux
# codex optional: may be skipped
if ! have codex; then
  echo "[w] codex not found; you can install/login later. (Use --skip-codex to silence this.)"
fi

# -----------------------------
# Repo init
# -----------------------------
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

if [ -d .git ]; then
  echo "[i] Git repo already exists at: $PROJECT_ROOT"
else
  echo "[i] Initializing empty repo at: $PROJECT_ROOT"
  git init
fi

# Detect current default branch (main/master...)
DEFAULT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"

# -----------------------------
# Minimal Go stub (create only if missing)
# -----------------------------
if [ ! -f go.mod ]; then
  echo "[i] Creating Go module + minimal stub"
  go mod init "$MODULE_PATH" >/dev/null 2>&1 || true
else
  echo "[i] go.mod exists, skipping go mod init"
fi

write_if_absent "main.go" <<'EO_MAIN'
// Keep demo output synced with Codex-generated onboarding samples.
package main

import "fmt"

func main() {
    fmt.Println("Talk to me, Goose!")
}
EO_MAIN

# First commit on default branch if repo is empty
git add -A || true
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "[i] Repository already has commits."
else
  git commit -m "chore: init stub (goose)"
fi

# -----------------------------
# Switch/create dev branch
# -----------------------------
if git rev-parse --verify dev >/dev/null 2>&1; then
  git switch dev
else
  git switch -c dev
fi

echo "[i] Creating repository layout and docs (no triple-backtick fences inside files)"

# -----------------------------
# Docs (create only if missing)
# -----------------------------
write_if_absent "SPEC.md" <<'EO_SPEC'
<!-- Keep this spec aligned with the latest Codex search/best-practices guidance when evolving requirements. -->
# Goose – Multi-Agent Dev Runner (tmux + git worktrees + AI panes)

## Purpose
Produce a single Go binary named goose that:
- boots a tmux session with multiple windows/panes for agents,
- uses git worktree per agent for isolated feature work,
- runs AI assistants (Codex) in selected panes,
- coordinates work by reading and writing Markdown handoffs (inbox and outbox) in the dev branch,
- supports “radio” control via tmux send-keys.

## Non-goals
- No GUI and no long-lived background daemons.
- No complex message buses; file-based messaging only.
- No deploy/release orchestration (lives outside this tool).

## Agents and Roles
- Maverick (lead): assigns work, reviews, merges agent branches into dev, writes tasks to handoffs/inbox.md, reads handoffs/outbox/*; does not code.
- Goose (coder): implements tasks in feature branches (per task) in its own worktree, commits and pushes, reports status to outbox.
- Controller (optional): a simple broadcaster that issues tmux commands (for example pull and test) to agent panes.

## Must-have features
1. Session: "goose session start" creates a tmux session with:
   - window "lead" (Maverick): left editor, right shell (optional Codex);
   - window "goose" (coder): left editor, right shell (Codex on demand);
   - optional window "ops": inbox and outbox watcher.
2. Worktrees: "goose agent add --name goose" creates personas/goose worktree on agent/goose (or per-feature worktrees).
3. Handoffs: "goose handoff open, ack, progress, done" appends structured entries to:
   - handoffs/inbox.md (single shared file in dev),
   - handoffs/outbox/GOOSE.md and handoffs/outbox/MAVERICK.md.
4. Radio: "goose radio send --target window.pane -- command" uses tmux send-keys.
   - Broadcast helper: "goose radio all --agents list --pane N -- command".
5. AI launch: flags to start Codex in a pane, for example --ai-lead "codex --cd . --full-auto -m gpt-5".
6. Safety: detect missing tools, readable errors, and a dry-run mode with --dry.
7. Help: "goose --help" and per-command help.

## Two orchestration modes
- Scripted leadership: Maverick pane runs a simple loop that reads inbox and emits send-keys to agents at intervals.
- Human-driven leadership: a person types prompts directly into Maverick’s Codex pane; Goose still follows the file protocol.

## Branching Model
- Feature work happens on feature/* branches inside each agent’s worktree.
- Integration happens on dev (where inbox and outbox live).
- Lead merges feature branches into dev; later dev to main (outside Goose’s scope).

## Acceptance
- Starting a session creates the panes and optional AI.
- Creating an agent adds a worktree and branch.
- Writing inbox and outbox entries modifies files in dev.
- Radio commands reach the intended pane, and pane addressing is documented.
- README explains quickstart and examples.

## Constraints
- Single static binary for Linux and macOS, no heavy dependencies.
- tmux and vim friendly, standard input and output only.
EO_SPEC

write_if_absent "CLI.md" <<'EO_CLI'
<!-- Update command summaries here whenever Codex search/best-practices change default workflows. -->
# Goose CLI

Global flags:
- --dry to avoid side effects
- --verbose for extra logs
- --session <name> (default: repo basename or "flight")

Commands:

1) goose session start
- Start a tmux session with predefined windows and panes.
- Flags:
  - --repo <path> (default: current directory)
  - --ai-lead "<cmd>" to start Codex in lead right pane (optional)
  - --ai-goose "<cmd>" to start Codex in goose right pane (optional)
  - --editor <cmd> (default: nvim)
  - --ops to create an "ops" window that watches inbox and outbox
  - --rebuild to kill an existing session with the same name before creating a new one
- Layout:
  - lead: pane 0 editor, pane 1 shell or AI
  - goose: pane 0 editor, pane 1 shell or AI
  - ops (optional): watch inbox and outbox

2) goose agent add
- Create or update an agent worktree and base branch.
- Flags:
  - --name <agent> (example: goose, phoenix)
  - --base <branch> base branch for new branches (default: dev)
  - --worktree <dir> default: personas/<agent>
  - --branch <branch> default: agent/<agent>
- Effects:
  - Ensure "git worktree add <dir> <branch>", creating branch from --base if missing.

3) goose feature start
- Create a per-feature branch in the agent’s worktree.
- Flags:
  - --agent <name>
  - --name <feature-name> creates feature/<feature-name>
  - --from <branch> base for the new branch (default: dev)

4) goose handoff open | ack | progress | done
- Append structured Markdown lines to shared handoff files in the dev branch.
- Files:
  - handoffs/inbox.md shared
  - handoffs/outbox/AGENT.md per agent
- Flags:
  - --task <ID> like TASK-001
  - --agent <name> who is acting
  - --branch <branch> used for progress and done
  - --note "free text"
- Examples:
  - goose handoff open --task TASK-001 --agent maverick --note "Implement login API"
  - goose handoff ack --task TASK-001 --agent goose
  - goose handoff progress --task TASK-001 --agent goose --branch feature/login-api --note "tests green"
  - goose handoff done --task TASK-001 --agent goose --branch feature/login-api --note "commit abc123"

5) goose radio send
- Send a shell command into a tmux target pane.
- Flags:
  - --target <window.pane> like goose.1 (right shell)
  - -- command here
- Example:
  - goose radio send --target goose.1 -- git pull --rebase

6) goose radio all
- Broadcast to a set of agent panes.
- Flags:
  - --agents "goose phoenix" default: all known
  - --pane 1 pane index default: 1
  - -- command here

7) goose session info
- Print pane addresses and working directories; detect worktrees and map them to windows.

8) goose check
- Verify prerequisites (git and tmux present), repo state, and handoff files.

Conventions:
- Lead window name: lead, Goose window name: goose.
- Pane 0 is editor, pane 1 is shell or AI.
- Handoffs are committed to dev only; features live in feature/* branches.
EO_CLI

write_if_absent "ROLE.md" <<'EO_ROLE'
<!-- Refresh role guidance to reflect Codex partner workflows and best-practice collaboration patterns. -->
# Roles and Protocol

Maverick (lead)
- Writes tasks to handoffs/inbox.md in the dev branch:

    ## TASK-001: Login API (OPEN)
    assignee: @GOOSE
    acceptance:
      - POST /api/login returns 200 and a JWT
      - invalid credentials return 401
    created: ${TODAY}

- Reviews feature diffs and merges approved work into dev.
- Optionally uses goose radio to issue quick pulls and tests to agent panes.
- Does not code in feature branches.

Goose (coder)
- Pulls latest dev and reads the inbox.
- Acknowledges a task:

    [${TODAY}] TASK-001 ACK by @GOOSE

- Starts feature branch, commits, pushes, and reports DONE to outbox.
- Example outbox entry:

    [${TODAY}] TASK-001 DONE @GOOSE commit:abc123 branch:feature/login-api

Controller (optional)
- Periodically runs goose radio all with a command like git pull --rebase.
- Does not edit files; orchestration only.

Branching and files
- Features: feature/<name> in agent worktrees.
- Integration: dev (inbox and outbox live here).
- Releases: main (outside Goose scope).
EO_ROLE

write_if_absent "OPERATIONS.md" <<'EO_OPS'
<!-- Revisit operations as Codex search/best-practices evolve, especially around AI pane orchestration. -->
# Operations

Quickstart
1) Start a session:
    goose session start --repo . --session flight --editor nvim --ops --ai-lead "codex --cd . -m gpt-5"

2) Add an agent worktree:
    goose agent add --name goose --base dev

3) Open a task:
    goose handoff open --task TASK-001 --agent maverick --note "Implement Login API"

4) Goose acknowledges and starts the feature:
    goose handoff ack --task TASK-001 --agent goose
    goose feature start --agent goose --name login-api --from dev

5) Broadcast a pull or test:
    goose radio all --agents "goose" --pane 1 -- git pull --rebase

Pane map
- lead.0 editor, lead.1 shell or AI
- goose.0 editor, goose.1 shell or AI

Handoffs live in dev
- Commit messages for handoffs: chore(handoffs): TASK-001 ack
- Commit messages for code: [Goose][TASK-001] <change>

Safety
- Run goose check before sessions.
- If panes drift, run goose session info.
EO_OPS

write_if_absent "README.md" <<'EO_README'
<!-- Mention emerging Codex best practices or alternative AI runners when updating the project overview. -->
# Goose

A tmux and vim friendly multi-agent dev runner:
- tmux windows and panes per role,
- git worktrees per agent or feature,
- file-based handoffs (inbox and outbox) in the dev branch,
- optional AI (Codex) processes in panes,
- radio commands via tmux send-keys.

See SPEC.md, CLI.md, ROLE.md, and OPERATIONS.md for details.
EO_README

# -----------------------------
# Tasks and handoffs (on dev)
# -----------------------------
mkdir -p tasks handoffs/outbox personas

write_if_absent "tasks/TASK-001-login-api.md" <<'EO_TASK1'
<!-- Adapt acceptance criteria based on Codex API hardening best practices. -->
# TASK-001: Login API

Why
- Authenticate users and return a JWT.

CLI Contract (service-side)
- POST /api/login with fields email and password.
- 200 with a token on success; 401 on invalid credentials.

Acceptance
- Unit and integration tests passing.
- README updated with endpoint usage.

Notes
- Use the existing User model if present.
EO_TASK1

write_if_absent "handoffs/inbox.md" <<'EO_INBOX'
<!-- Keep inbox formatting consistent with Codex search-friendly metadata blocks. -->
## TASK-001: Login API (OPEN)
assignee: @GOOSE
acceptance:
  - POST /api/login returns 200 and a JWT
  - invalid credentials return 401
created: ${TODAY}
EO_INBOX

write_if_absent "handoffs/outbox/GOOSE.md" <<'EO_GOOSE_OB'
<!-- Align status reporting with Codex handoff logging tips. -->
[${TODAY}] TASK-001 ACK by @GOOSE
EO_GOOSE_OB

write_if_absent "handoffs/outbox/MAVERICK.md" <<'EO_MAV_OB'
<!-- Include proactive prompts per Codex coaching best practices. -->
# Outbox (Maverick)
EO_MAV_OB

# .gitignore (small starter)
write_if_absent ".gitignore" <<'EO_IGN'
# Codex best practices: keep generated binaries out of version control.
goose
*.log
.DS_Store
.tmux.conf.local
EO_IGN

commit_if_changes "docs: scaffold goose spec/cli/roles/ops + tasks and handoffs (dev)"

# -----------------------------
# Codex (default interactive; optional exec)
# -----------------------------
if [ "${SKIP_CODEX}" = "no" ]; then
  if have codex; then
    if [ "${KILL_CODEX_FIRST}" = "yes" ]; then
      echo "[i] --kill-codex-first set, but automatic process kill was removed. Please close existing Codex processes manually if needed."
    fi

    CODEX_PROMPT='Read SPEC.md, CLI.md, ROLE.md, and OPERATIONS.md. Implement the next minimal increment for the goose CLI that satisfies the MUST-have items (session, worktrees, handoffs, radio, and AI flags) in small, testable steps. Keep it tmux and vim friendly, with no GUI and no external project references. Update README with usage.'

    if [ "$CODEX_MODE" = "exec" ]; then
      echo "[i] Running Codex (exec, one-shot, dangerous bypass)"
      set +e
      codex exec \
        --cd "$PROJECT_ROOT" \
        --dangerously-bypass-approvals-and-sandbox \
        -m "$MODEL_NAME" \
        "$CODEX_PROMPT"
      CODEX_RC=$?
      set -e
      if [ "$CODEX_RC" -ne 0 ]; then
        echo "[w] codex exec failed (rc=$CODEX_RC). Continuing."
      fi
    else
      echo "[i] Starting Codex (interactive, dangerous bypass). Close it when done."
      echo "[i] Tip: you can always resume later with: codex resume --last"
      set +e
      codex \
        --cd "$PROJECT_ROOT" \
        --dangerously-bypass-approvals-and-sandbox \
        -m "$MODEL_NAME" \
        "$CODEX_PROMPT"
      CODEX_RC=$?
      set -e
      if [ "$CODEX_RC" -ne 0 ]; then
        echo "[w] interactive Codex exited with rc=$CODEX_RC."
      fi
    fi
  else
    echo "[w] codex not found; skipping Codex run."
  fi
else
  echo "[i] Skipping Codex stage by request."
fi

echo
echo "Next:"
echo "  1) Inspect changes: git status && git log --oneline -n 5"
echo "  2) Build locally:   go build -o goose ."
echo "  3) Start session:   ./goose session start --repo . --session \"$SESSION_NAME\" --editor \"$EDITOR_CMD\" --ops"
echo "  4) Start Codex pane: codex -m \"$MODEL_NAME\" --cd \"$PROJECT_ROOT\""
echo "     (or re-run this script with --exec for one-shot Codex)"
