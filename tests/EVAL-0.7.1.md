# Evaluation — TokenOptimizer UNIVERSAL 0.7.1

Date: 2026-11-20
Target: Codex + Claude Code on Windows PowerShell 5.1.
Scope: one-pass orchestration and source-excerpt relevance correction. The project/language router remains universal-by-layout and language; the current native implementation is Windows PowerShell, not a Linux/macOS release.

## What changed

- Multi-file tasks default to one integrated router + slicer invocation when task concepts or API terms are available.
- The slicer prioritizes exact -Symbols above lifecycle API -Terms, and both above optional broad adapter patterns.
- Explicit symbols and task terms contribute at most one representative hit per file. Repeated references to one service do not consume all snippet slots.
- API/method/event terms such as GetAsync, UpdateAsync, PlayerAdded and OnServerEvent rank above broad service-name matches such as DataStoreService.
- The skill permits at most one targeted second extraction after reviewing the initial output and notices.
- The integrated flow avoids separate plan-reading shell calls, nested PowerShell launches, and unnecessary repeated slicer calls.

## Automated regression tests

Test file: tests\Test-TokenOptimizer-0.7.ps1

Coverage:
1. Router PowerShell 5.1 parser compatibility.
2. Slicer PowerShell 5.1 parser compatibility.
3. Multi-language discovery and common exclusions.
4. Symbol extraction, language fences and bounded context.
5. Route-score ordering before file limits.
6. Exact lifecycle symbols outrank generic header terms.
7. Terms-only GetAsync/UpdateAsync extraction, even when DataStoreService appears earlier in the file.
8. Documentation opt-in.
9. Path traversal, absolute path, dependency and backup path rejection.
10. Integrated route + slice.
11. Project source files remain unchanged.

Latest Codex run: **11 passed | 0 failed**.
Latest Claude run after syncing this exact terms-priority revision: **11 passed | 0 failed**.

## Live RobloxGraph one-pass smoke test

Command used only task-grounded terms; no -Symbols and no broad Roblox adapter:
- Query: INVENTORY EQUIPMENT CONSUMABLE STORAGE
- Terms: GetAsync UpdateAsync PlayerAdded PlayerRemoving OnServerEvent FireServer
- Limits: 10 candidates, 8 snippets/file, 3 context lines, 40 lines/file, 160 total lines.

Result on [local test project path omitted]:
- Router: 10 seed candidates; 2,096 files and 50 directories visited; 92 eligible; no truncation.
- Slicer: 10 plan candidates opened; 3 matched and emitted excerpts.
- Output: 69 source lines.
- Router: 397 ms.
- Slicer: 451 ms.
- Complete terminal process: 4.19 s, including PowerShell startup.

The three matched files were EquipmentService.server.luau, InventoryItemService.server.luau and InventoryClient.client.luau. The excerpts showed GetAsync/UpdateAsync load/save calls, server equip handler, PlayerAdded/PlayerRemoving lifecycle and client FireServer requests. This is a local smoke test, not an end-to-end Codex response-time benchmark.

## Previous end-to-end result that triggered this patch

The user-provided Codex comparison for 0.7 measured:
- With TokenOptimizer: 3m47s.
- Without TokenOptimizer: 1m14s.
- Observed ratio: about **3.07x slower with the skill**.

The 0.7 run performed five overlapping extraction passes and encountered several shell-wrapper/PowerShell errors while reopening the plan. Version 0.7.1 changes those behaviors directly.

The same full end-to-end Codex A/B task has **not yet been rerun on 0.7.1**. Therefore no measured end-to-end response-time speedup is claimed yet.

## Token economy and answer quality

Actual provider input/output token counts were not available in the supplied Codex logs. The line budget is a context-size guard, not an exact tokenizer measurement. No token-saving percentage is claimed.

The patched skill has not yet completed a paired post-patch model evaluation. Therefore preserved or improved intelligence/answer quality is not yet proven. Validate with the same model, reasoning setting, project snapshot and correctness rubric.

## Known limitations

- Routing ranks path/name metadata; it is not semantic search, AST analysis, a compiler or a dependency graph.
- Excerpt matching is lexical and bounded. It does not resolve imports, overloads or runtime references.
- Broad task terms can still select noisy candidates. Prefer distinctive subsystem terms and exact symbols once grounded.
- Current implementation target is Windows PowerShell 5.1/7 on Windows.
