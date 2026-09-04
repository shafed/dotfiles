---
name: pulsar-workflow
description: "Work on and verify the AI Devance Pulsar repository using its actual project state and CI oracle. Use for implementation, debugging, verification, or continuation work in github.com/aidevance/pulsar / shafed/pulsar. Read CLAUDE.md and docs/STATUS.md first; consult the larger spec/architecture/migration documents only as needed. Before calling implementation complete, run the bundled verification script."
user-invocable: true
argument-hint: [optional Pulsar task, stage, or failure]
---

1. Confirm this is Pulsar: `go.mod` must declare `module github.com/aidevance/pulsar`. If not, stop using this skill.
2. Read `CLAUDE.md`, then `docs/STATUS.md`. They are the entry points for repository constraints and current work. Do not reconstruct project state from the whole tree when STATUS already records it.
3. Use `docs/SPEC.md`, `docs/ARCHITECTURE.md`, `docs/MIGRATION_PLAN.md`, and `docs/EXPERIMENTS.md` only when the current change needs their contracts, rationale, stage criteria, or experimental evidence.
4. Treat `refs/hop-legacy` and `refs/aidevance-vpn` as read-only references. Never copy a subsystem wholesale. Before reusing code, preserve Pulsar's current architecture and check license/dependency constraints described in `CLAUDE.md`.
5. Keep implementation, tests, and invariant/guard changes aligned. If implementation reveals a real architectural deviation or closes a migration-stage decision, update the corresponding project document; do not add narrative documentation just to describe routine edits.
6. Before claiming the task or stage complete, run `bash .claude/skills/pulsar-workflow/scripts/verify.sh` (or this skill's resolved script path if installed globally). Treat any failed check or Xray preflight mismatch as incomplete verification.
7. The verification script mirrors the repository CI: vet, formatting, builds for Linux/Windows/macOS, real-time lint, tests, then negcheck. Fix the first causal defect rather than weakening the oracle.
8. If a check cannot run because the local environment lacks the pinned Xray or required Go version, report that as an environment verification gap instead of treating skipped component coverage as success.
