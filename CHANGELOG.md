# Changelog

## 0.7.3 — CONTENT DISCOVERY + COVERAGE-AWARE EXTRACTION (2026-11-20)
- Extended cross-language routing from path/name metadata to bounded lexical content discovery.
- Added CamelCase-aware matching for identifiers such as GetAsync, InventoryIcons and EquipmentModels.
- Separated subsystem/query concepts from source-content terms to reduce generic event-name false positives.
- Added explicit counts for eligible files, ranked candidates, selected candidates, eligible-but-unranked files and ranked-but-unselected files.
- Added independent metadata/content truncation flags and bounded source-content discovery limits.
- Reworked candidate selection as a relevance/term-coverage set-cover pass with directory diversity.
- Reworked slicing to inspect all allowed plan candidates before allocating output lines, establish a per-file evidence floor and distribute remaining lines by weighted relevance.
- Added distinct-pattern selection and priority-first range emission so later action, validation and persistence branches are less likely to be displaced by early setup code.
- Added task-conditioned priority for GetAsync/UpdateAsync, PlayerAdded/PlayerRemoving/BindToClose, equip/unequip, loaded-state, ownership, cooldown and noSave protection.
- Raised defaults to 24 candidate files, 16 match groups/file, one context line, 60 lines/file and 400 total source lines; all output limits and omissions remain visible.
- Expanded regression suite to 15 checks, including generic-name discovery, CamelCase, event-noise filtering, fair output distribution and synthetic load/save/action/guard/lifecycle evidence.
- Latest RobloxGraph local smoke: 90 eligible files, all 90 content-scanned, 19 ranked/selected/opened/matched, 71 eligible-but-unranked, no scan truncation, 400 lines emitted, router 497 ms, slicer 5,457 ms, complete PowerShell process 7.74 s.
- Script tests do not certify model intelligence. Provider token counts and a same-model end-to-end 0.7.3 A/B evaluation are still unavailable.

## 0.7.2 — RTK BYPASS + ONE-PASS LIFECYCLE COVERAGE (2026-11-20)
- Added an explicit machine-level RTK exception for TokenOptimizer PowerShell scripts. Run them directly with &, not through rtk run/proxy or encoded-command wrappers.
- Made the skill avoid rereading SKILL.md, README.md and RTK.md after instructions are loaded.
- Condensed the automatically loaded SKILL.md from 119 to 55 lines; detailed docs and EVAL retained.
- Tuned the default lifecycle profile to collect load/save APIs, player lifecycle events and client/server actions in one integrated call.
- Added extension-aware comment-line suppression and tests for action branches, lifecycle priority and terms-only persistence APIs.
- The user-provided full Codex run took 42 seconds with 0.7.2, compared with 1m14s without the skill and 1m20s with 0.7.1. The report's own excerpt count was internally inconsistent; this is a user-reported wall-clock comparison, not a quality or token-count measurement.
- Provider token counts and a same-model quality comparison were unavailable.

## 0.7.1 — ONE-PASS EXECUTION + RELEVANCE FIX (2026-11-20)
- Changed the default agent workflow to one integrated route-and-slice invocation for multi-file tasks.
- Bounded refinement to one targeted second extraction.
- Ranked exact symbols above task terms and optional broad API edges.
- Added deduplication and lifecycle-priority tests.
- Preserved bounded file/line limits, read-only project behavior and path validation.

## 0.7.0 — UNIVERSAL (2026-11-20)
- Replaced the Roblox/Graphify-specific core router with project-root discovery across common languages and layouts.
- Added bounded path/name scanning and common backup/dependency/cache/build/generated/reparse-point exclusions.
- Made documentation opt-in.
- Rebuilt the source slicer for general identifiers and terms, bounded output and language-aware excerpts.
- Added scan/output truncation notices and a cached .NET scanner helper.
