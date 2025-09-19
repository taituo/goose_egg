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
# Runtime flags (defaults)
#   --exec              -> Codex non-interactive one-shot
#   --kill-codex-first  -> (no-op) preserved for compatibility; prints a note
#   --skip-codex        -> skip Codex stage entirely
# -----------------------------
CODEX_MODE="interactive"   # or "exec"
KILL_CODEX_FIRST="no"
SKIP_CODEX="no"

for arg in "$@"; do
  case "$arg" in
    --exec) CODEX_MODE="exec" ;;
    --kill-codex-first) KILL_CODEX_FIRST="yes" ;;
    --skip-codex) SKIP_CODEX="yes" ;;
    *)
      echo "Unknown flag: $arg" >&2
      echo "Supported: --exec | --kill-codex-first | --skip-codex" >&2
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
