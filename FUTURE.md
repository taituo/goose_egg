# Soft Eggs → Hard Eggs → One-Shot Multi-Agent Apps

This note captures the forward plan for evolving Goose Egg into a repeatable factory for microservices and other multi-agent projects. The high-level lifecycle stays true to the EGG → Oneshot → APP thesis from `FEAT_SPEC.md`.

## 1. Soft Egg Staging

Soft eggs are editable recipes. Before we harden an egg, we should:

1. **Design the variant** – record target runtime, provider, persona set, and default prompts inside `config/variables.json`.
2. **Prototype templates** – add docs/snippets under `templates/` that express the experience (specs, CLI help, task seeds, handoffs).
3. **Smoke render** – run `python3 render.py --variant <name>` and validate the script with `--verify-egg` / `--extract-egg`.
4. **Iterate in sandbox** – execute the rendered oneshot against a scratch workspace, capture gaps, update the soft egg.
5. **Preview docs** – ensure the rendered README/specs read clearly; update narratives before sealing.

Repeat until the variant is deterministic, well-documented, and aligned with the latest Goose guidance.

## 2. Hardening Checklist

Once the soft egg stabilises:

- Lock configuration by tagging the variant (e.g. `egg_schema`: `v1.1`, `variant`: `go-http`).
- Generate a hard egg artifact (single script/binary) with `render.py`.
- **Verify**: `./<oneshot> --verify-egg` must pass.
- **Sign**: add minisign/cosign signatures and optionally attach SBOM/provenance files.
- **Archive**: publish the tarball manifest + signature alongside the oneshot.
- **Document**: update README/CHANGELOG to reflect which hard egg was cut and why.

The goal is to make the hard egg immutable—consumers run it, but the source of truth remains the soft egg in git.

## 3. One-Shot Microservice Menu

With the Goose pipeline we can author several multi-agent microservices as hard eggs:

| Variant | Description | Agents | Stack |
|---------|-------------|--------|-------|
| `go-http` | HTTP JSON API skeleton with health check, status endpoint, and Makefile | Maverick (lead), Goose (coder), Ops (SRE) | Go + standard library |
| `node-queue` | Queue-backed worker that processes tasks with TypeScript + BullMQ | Maverick, Goose, Tower (ops) | Node.js + Redis |
| `py-ops` | Incident-response CLI that automates runbooks | Maverick, Goose, Ops, Analyst | Python + Typer |
| `docs-only` | Knowledge base generator with rotating writers | Maverick, Goose (writer), Editor | Markdown only |

Each variant shares the same handoff contract but customises tasks/snippets.

## 4. Multi-Agent Scenarios

Soft eggs should capture persona wiring up front:

- **Branching** – ensure worktree layout maps agent names → `personas/<agent>`.
- **Handoffs** – preseed inbox/outbox templates with checklists for each persona.
- **Prompts** – embed suggested Codex prompts per agent (e.g., Goose receives testing focus, Ops emphasises deploy).
- **Ops Hooks** – for service variants, add optional scripts (`./scripts/apply.sh`, `./scripts/rollback.sh`).

## 5. Shipping Flow

1. Draft/update soft egg.
2. Run `make test` (now includes pytest verification).
3. Cut hard egg (`render.py` → oneshot) and sign.
4. Publish to GitHub with updated docs (see README “Updating GitHub”).
5. Announce availability + changelog entry.

Following this pattern keeps the egg authoritative while letting teams oneshot new multi-agent services with a single script.
