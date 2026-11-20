# Evaluation — TokenOptimizer 0.7.2

Date: 2026-11-20
Target: Codex and Claude Code on Windows PowerShell 5.1.
Scope: integrated single-pass workflow, RTK invocation fix and lifecycle evidence selection. The core is universal by project layout/file format; native scripts remain Windows PowerShell, not Linux/macOS.

## Changes

- Integrated route + slice is the default for multi-file tasks with grounded query/terms.
- Machine-level RTK.md contains a narrow exception for TokenOptimizer scripts. Direct PowerShell call-operator invocation is required; no rtk run/proxy, nested PowerShell or encoded command.
- Skill instructions tell the agent not to reread SKILL.md, README.md or RTK.md after already loaded.
- Condensed the automatically loaded SKILL.md from 119 to 55 lines (about 54% fewer instruction lines); this is a prompt-size proxy, not a token measurement.
- Slicer ranks explicit symbols and lifecycle/event APIs above generic terms.
- Task terms may contribute up to four representative matches per file, enough to surface a handler declaration, argument validation and action branches.
- Comment-only matching is skipped using extension-aware rules; Markdown headings are not treated as code comments.
- One initial extraction, with at most one evidence-based targeted second extraction.

## Regression tests

File: tests\Test-TokenOptimizer-0.7.ps1

Coverage:
1. Router PowerShell 5.1 syntax.
2. Slicer PowerShell 5.1 syntax.
3. Multi-language discovery and default exclusions.
4. Symbol extraction, language fences, paths containing spaces and bounded context.
5. Candidate score ordering before file limits.
6. Exact lifecycle symbols outrank generic header terms.
7. Terms-only GetAsync/UpdateAsync extracts both load and save evidence.
8. Action terms find equip and unequip branches; comment-only mentions are excluded.
9. Documentation opt-in.
10. Traversal, absolute path, dependency and backup path rejection.
11. Integrated route + slice.
12. Source integrity/read-only behavior.

Latest Codex run: **12 passed | 0 failed**.
Latest Claude regression result after syncing the exact final revision: **12 passed | 0 failed**.

## Live RobloxGraph one-pass smoke test

Command used:
- Query: INVENTORY EQUIPMENT CONSUMABLE
- Terms: GetAsync, UpdateAsync, PlayerAdded, PlayerRemoving, BindToClose, OnServerEvent, FireServer, action, equip, unequip
- Limits: 10 files, 8 snippets/file, 5 context lines, 60 lines/file, 180 total lines
- No exact -Symbols and no broad Roblox adapter.

Result on [local test project path omitted]:
- Router: 7 candidates; 2,096 files and 50 directories visited; 92 eligible; no truncation.
- Slicer: 7 candidates opened; 5 matched files; 177 source lines emitted.
- Router: 388 ms.
- Slicer: 472 ms.
- Combined route + slice: **860 ms**.
- Full terminal process: 4.27 s including PowerShell startup.

Evidence included:
- EquipmentService DataStore load with GetAsync and safe noSave handling on load failure.
- Equipment snapshot save with UpdateAsync, Owned and Equipped fields.
- Server OnServerEvent equip path including throttling, item lookup, ownership/quantity validation, slot update and visual change.
- Server unequip branch and slot validation.
- InventoryClient sends equip/unequip/use requests.
- InventoryItemService GetAsync/UpdateAsync, item-use validation, PlayerAdded/PlayerRemoving and BindToClose.

This is a single local pipeline smoke test, not a full Codex response-time measurement.

## End-to-end A/B results

User-provided Codex measurements:
- 0.7 with TokenOptimizer: **3m47s**.
- 0.7.1 with TokenOptimizer: **1m20s**.
- No skill: **1m14s**.

The 0.7.1 run attempted multiple RTK shell forms, had command failures, and performed a second extraction. Version 0.7.2 changes the machine RTK instruction and one-pass lifecycle selection to target those issues.

A complete Codex end-to-end task using 0.7.2 has **not yet been measured**. Do not claim it is faster than the no-skill baseline until that paired run completes.

## Token economy and reasoning quality

The 0.7.1 run emitted 247 source lines across two extraction passes. The 0.7.2 one-pass smoke test emitted 177 source lines (about 28% fewer extracted lines). This is a context-size proxy, **not** a measured 28% token saving.

Provider input/output token counts are unavailable. The regression suite verifies extraction and safeguards, not model-answer correctness. Preserved or improved intelligence remains unproven until a paired same-model, same-reasoning, same-repository evaluation with a correctness rubric is run.

## Known limits

- Router is based on path/name metadata, not semantic search, ASTs or a dependency graph.
- Slicer uses lexical identifiers/terms and bounded context; it does not resolve imports or runtime references.
- Broad terms can still select irrelevant files; use distinctive domain terms.
- Current native implementation targets Windows PowerShell 5.1/7.
