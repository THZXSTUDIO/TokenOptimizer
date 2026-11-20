# Evaluation — TokenOptimizer MEGABRAIN MAX 0.6

## Scope
Version 0.6 keeps the Graphify-first, one-hop routing model and adds lazy filename fallback, score-aware candidate prioritization, and bounded source excerpts. It does not read or edit Roblox source during routing; the separate slicer reads selected source files locally and emits only limited excerpts.

## Automated validation
- PowerShell 5.1 syntax: passed.
- Router regression suite 0.5: **10 passed | 0 failed**.
- Version 0.6 suite: **8 passed | 0 failed**.

The 0.6 suite covers parser compatibility, plan-only source access, snippet filtering, seed-before-neighbor prioritization, graph-score ordering, global output limits, no-match behavior without broadening to src, lazy fallback suppression when enough Graphify seeds exist, and source-file SHA-256 integrity.

## Live RobloxGraph smoke test
Query: INVENTORY EQUIPMENT CONSUMABLE LOOT

- Graph snapshot: 912 nodes / 1,733 links.
- Selected: 7 seeds, 2 one-hop neighbors, 4 domains.
- Filename fallback: **0 files / 0 directories** when Graphify supplied at least 4 valid seeds.
- Source contents read by router: 0.
- Router run for the final smoke test: 1,240 ms (cold/variable run; not used as the benchmark median).
- Plan: TokenOptimizer/AgentPlan-0.6-20261120-080445-204.md.

The source-slice smoke test used the live plan and exact inventory/equipment/loot identifiers:
- 9 candidates in the plan.
- 6 files opened before the 55-line task budget was reached.
- 6 files contained matches.
- 55 lines emitted; no whole-file dumps.
- Included EquipmentService, InventoryClient, InventoryItemService, DungeonLoot, and loot UI consumers.

## A/B router benchmark
Same project snapshot, query, host PowerShell, and five sequential runs per version. Median wall time:

| Version | Median | Fallback scan |
|---|---:|---:|
| 0.5 | 621 ms | 170 files / 38 directories |
| 0.6 | 627 ms | 0 files / 0 directories |

The 0.6 router was approximately 1% slower in this sample, which is effectively near parity within machine/cache variation. It selected an additional neighbor and avoided the filename fallback walk. This is not evidence of faster end-to-end model responses.

## Token and answer-quality limitations
Actual model input/output token usage and answer correctness were not available from these local PowerShell tests. Do not claim a measured token-saving percentage or prove that intelligence is fully unchanged from routing counts alone. The demonstrated context reduction is the bounded excerpt output (55 code lines in the live smoke test), not a tokenizer-based token measurement.

## Safety and rollback
- Game source files remained unchanged in automated tests (SHA-256 before/after).
- Router path checks reject traversal, blocked folders, missing files, and reparse points.
- The 0.5 backup was retained at:
  C:\Users\Administrator\Documents\TokenOptimizer-v0.5-backup-20261120-0720\Codex
  and
  C:\Users\Administrator\Documents\TokenOptimizer-v0.5-backup-20261120-0720\Claude.
- No project sync/watch job or Graphify regeneration was run.
