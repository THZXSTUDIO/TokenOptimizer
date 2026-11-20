# EVAL 0.7.3 — ROBLOXGRAPH SMOKE + REGRESSION

Date: 2026-11-20  
Host: Windows PowerShell 5.1  
Project: `[local test project path omitted]`  
Scope: Inventory, equipment, consumables, lifecycle and persistence  
Execution: one integrated router + slicer invocation; source code read-only.

## Regression result

- PowerShell parser: 4/4 scripts parsed with no syntax errors.
- Regression suite: **15 passed | 0 failed**.
- Coverage includes multi-language discovery, generic-name source discovery, CamelCase identifiers, generic event-noise filtering, path safety, line-budget distribution, lifecycle prioritization, load/save API extraction, equip/unequip actions, loaded/ownership/rate-limit/save-protection guards, shutdown hooks, integrated invocation and source integrity.

These tests validate deterministic script behavior on synthetic fixtures. They do not prove that a model preserves or improves reasoning quality.

## Latest integrated local smoke test

Exact current-run terminal summaries:

```text
TOKENOPTIMIZER UNIVERSAL 0.7.3 | ranked=19 seeds=19 unselected=0 eligibleUnranked=71 scanned=2096 dirs=50 eligible=90 contentFiles=90 sizeBudget=1387361 time=497ms truncated=False contentTruncated=False stages=load:234/scan:165/rank:45/plan:48

TOKENOPTIMIZER SLICES UNIVERSAL 0.7.3 | candidates=19 opened=19 matched=19 lines=400 perFileBudget=8 time=5457ms
```

Remote PowerShell process runtime: **7.74 s**.

Interpretation:
- 2,096 filesystem entries and 50 directories visited.
- 90 eligible source/config files found and all 90 passed through bounded content discovery.
- 19 files ranked as task-relevant; all 19 were selected, opened and matched.
- 71 other eligible files did not rank on the supplied lexical query/terms. They were not deeply inspected by the slicer. This is an explicit coverage boundary, not proof those files are irrelevant.
- No metadata or content scan truncation.
- Aggregate size budget accounted for 1,387,361 bytes of eligible files. This is an accounting metric, not the amount of bytes actually read.
- Slicer output reached its 400-line ceiling; lower-priority context may have been omitted. Every selected candidate was opened before the output budget was distributed.

## Evidence surfaced

Primary equipment service:
- Snapshot contains `Owned` and `Equipped`.
- `UpdateAsync` save and `GetAsync` load both surfaced.
- On load failure, `st.noSave = true` protects the existing save from being overwritten with empty data.
- Remote handler validates argument types/length, waits for loaded state, applies a 0.3-second request throttle, checks item ownership, and handles equip/unequip branches.
- `PlayerAdded`, `PlayerRemoving` and `BindToClose` hooks surfaced.

Consumable inventory service:
- Builds `ConsumableInventory`, loads profile via `GetAsync`, and saves snapshots with `UpdateAsync`.
- Handles the use RemoteEvent and validates consumable IDs and loaded state.
- `PlayerAdded`, `PlayerRemoving` and `BindToClose` hooks surfaced.

Related evidence:
- Client calls for equip, unequip and use.
- Equipment model/visual helpers and client FX.
- Player progress persistence and power progression have separate load/save lifecycles.
- Dungeon loot and consumable-drop integration appeared in the ranked candidate set.

The local smoke test confirms that the extraction engine emitted these evidence paths. It is not a full semantic audit of all 90 eligible files, and it does not establish whether independent DataStores share keys or overwrite one another.

## Performance and token claims

- Router: 497 ms.
- Slicer: 5,457 ms.
- Combined measured route + slice: the two phases total 5.954 s. 
- Full PowerShell process: 7.74 s, including process startup and wrapper overhead.
- Actual model/provider input and output token counts were not available.
- Source-line counts are not token counts.
- The skill prompt is 53 lines, down from the previous 119-line original (about 55% fewer instruction lines). This is an instruction-size proxy, not an exact token measurement.

The user-reported 0.7.2 Codex comparison was 42 seconds with the skill versus 1m14s without the skill and 1m20s with 0.7.1. The latest 0.7.3 result above is a local script pipeline smoke test, not an end-to-end Codex model response. A fair speed/intelligence comparison still requires rerunning the same Codex task with the same model, reasoning setting and repository snapshot after restarting Codex.

## Known limitations

- Lexical discovery is not AST parsing, semantic indexing, an import graph or runtime tracing.
- 71 eligible files were not ranked by the current query/terms; a different query may surface additional relevant files.
- The slicer emitted exactly 400 lines and reports the output-budget notice. It can omit low-priority details even after opening every selected candidate.
- Language comment recognition and API/action detectors are lexical heuristics; unusual formatting or project-specific abstractions can be missed.
- No provider token telemetry or paired answer-quality rubric was available.
