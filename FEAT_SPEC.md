# EGG → Oneshot → APP
**Document version:** v1.0  
**Reference:** Goose project (showcase): https://github.com/taituo/goose

---

## 0) Executive Summary

- **Thesis:** The most durable way to build projects is **EGG → Oneshot → APP**.  
  - **EGG** = permanent recipe of templates + config + manifest.  
  - **Oneshot** = single-file bootstrap script or binary generated from the egg.  
  - **APP** = final application, deterministically generated from the Oneshot.

- **Why not keep a GOOSE wrapper?** Wrappers (agent/tools) age quickly: libraries, models, and CLIs change. Maintenance and versioning become heavy.  
  → **Goose is useful as proof** and as a showcase, but not as a permanent artifact.

- **Principle:** Only **EGG** should be permanent. Oneshot is always generated from the Egg. App is always generated from the Oneshot.  
  If you want a “Goose,” generate it from the Egg for the current ecosystem.

- **Extensibility:** An Egg can hatch one or **many** Oneshots (multi-oneshot) for different languages, stacks, or providers — without maintaining a separate wrapper framework.

---

## 1) Background and Problem Statement

- Agent/wrapper layers (like Goose) are good for experimentation, but:
  - **Versions change** (models, SDKs, CLIs),  
  - **Ecosystems evolve** (policies, costs, rate limits),  
  - **Maintenance piles up** (bugs, deprecations).

**Result:** The wrapper layer ages faster than the apps it creates.

**Solution:** Standardize only the **Egg** as the permanent source of truth. Everything else is generated: Oneshot (throwaway), App (final product).

---

## 2) Model: EGG → Oneshot → APP

```
[EGG] --render--> [ONESHOT] --hatch--> [APP]
  ^                                          |
  |--(reverse via hatchmap/signature)—-------|
```

- **EGG**: templates, variables (YOLK), manifest (SHA256), optional signature, optional hatchmap for reverse.  
- **ONESHOT**: single script/binary that verifies manifest, renders templates, writes files idempotently, creates the App.  
- **APP**: ready-to-build project.

---

## 3) Why this model is better than a persistent wrapper (GOOSE)

1. **Less maintenance:** Egg is small and stable. Oneshot is always generated fresh.  
2. **Compatibility:** Update templates only; new Oneshot instantly matches ecosystem.  
3. **Determinism:** Manifest + SHA ensure repeatability.  
4. **Multiplication:** Multi-oneshot: one Egg → many variants.  
5. **Trust:** Signatures, SBOM, provenance.  
6. **Proof:** Goose repo itself was generated → wrapper is demo, not core.

---

## 4) Soft Egg vs. Hard Egg

- **Soft Egg:** editable variables (YOLK), execution logic protected by checksum. Good for developers.  
- **Hard Egg:** sealed, read-only, runs → generates app. Good for end-users.  
- **Principle:** one permanent source, generated artifacts layered on top.

---

## 5) Reverse (APP → EGG)

- Embed hatchmap and/or self-describing payload.  
- Command `--extract-egg` recovers templates + variables + manifest.  
- Ensures reproducibility and audit trail.

---

## 6) Extending: Oneshotting Goose itself

- Add capability in Egg to generate Goose-like Oneshot as demo.  
- Reference: https://github.com/taituo/goose  
- Goose then is generated, not maintained permanently.

---

## 7) Multi-Oneshot

- Targets: Go, Node, Python  
- Providers: OpenAI, Anthropic, Ollama  
- Profiles: minimal, http, cli, service  

Variants are handled in Egg. Oneshot just renders the chosen one.

---

## 8) Maintenance Principles

- **Thin default path:** Only README, minimal code files, .gitignore, manifest.  
- **Idempotence:** write-if-absent, dry-run support.  
- **Single source of truth:** All user values in variables.json (YOLK).  
- **Schema versioning:** egg_schema: vN.  
- **Light testing:** smoke builds, golden templates, idempotent reruns.  
- **Periodic cleanup:** remove unused flags/variants.

---

## 9) Security and Audit

- Manifest + SHA256.  
- Signature (minisign/cosign).  
- SBOM/provenance optional.  
- Secrets handled as environment variables, never written to disk without user consent.

---

## 10) Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Ecosystem changes | Update Egg templates, regenerate Oneshot |
| Tool zoo | No permanent wrappers; all generated |
| Loss of determinism | Manifest + fixed timestamps |
| Complexity | Thin defaults, extras only with flags |
| Trust | Signatures, verify mode |
| Recoverability | `--extract-egg` |

---

## 11) Governance

- Version Egg schema (v1, v2…).  
- Maintain CHANGELOG.  
- Deprecate with clear lifecycle.

---

## 12) Usage Examples

```
egg oneshot --target go --profile minimal | sh
egg oneshot --target go --profile http --with docker --with ci | sh
egg oneshot --target go,node --profile http
```

---

## 13) Agent Brief (for AI tooling)

**Goal:** Generate Oneshot from Egg; Oneshot generates deterministic App.

**Steps:**  
1. Read Egg (templates, variables, manifest).  
2. Select variant (target, provider, profile).  
3. Verify schema, manifest, signature.  
4. Render templates.  
5. Write files idempotently.  
6. Print manifest.  
7. If `--extract-egg`, recover payload.

**Guarantees:** Determinism, idempotence, audit-friendly, no secret leakage.  
**Forbidden:** Overwrites without force, ignoring signature errors.  
**Allowed:** Multi-oneshot, provider-agnostic snippets.  
**Definition of Done:** App builds/tests out of box, manifest matches.

---

## 14) Implementation Plan

- Define Egg schema v1.  
- Pack Oneshot (script/binary with payload).  
- Support multi-oneshot flags.  
- CI: Soft Egg → Hard Egg with signature.  
- Tests: smoke, golden, idempotence.

---

## 15) FAQ

**Q: Why not keep Goose alive?** Because it locks you to a fast-moving ecosystem. Egg stays stable.  
**Q: Can I still use Goose?** Yes — generate a Goose-oneshot when needed.  
**Q: How to prove determinism?** Manifest + SHA + reproducible builds.  
**Q: How about secrets?** Handle via env vars, not in repo/disk.

---

## 16) References

- Goose showcase: https://github.com/taituo/goose  
- This document: “Egg → Oneshot → App” (v1.0)

---

