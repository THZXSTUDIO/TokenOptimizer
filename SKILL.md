---
name: token-optimizer
description: Multi-file coding task router and bounded, coverage-aware source extractor for Codex and Claude Code. Use for cross-file tasks without reducing the user's requested reasoning depth.
---

# TokenOptimizer 0.7.3

## Use
Use for multi-file, cross-module, architecture, dependency tracing, debugging, or unclear-scope tasks. Skip general questions and narrow one-file tasks with known paths.

## Rules
1. Preserve the complete user task, acceptance criteria, constraints, and safety requirements. Search terms never replace the requested analysis.
2. Prefer one integrated route+slice invocation. Do not split stages unless exact symbols must be selected from plan evidence.
3. Invoke scripts directly with PowerShell `&`; never use RTK, `rtk run/proxy`, nested PowerShell, script blocks, or `-EncodedCommand`.
4. Do not reread SKILL.md, README.md, or RTK.md after they are loaded. Do not run `which rtk` or `rtk --help`.
5. Use 3–12 distinctive subsystem/file concepts in Query. Use task-grounded APIs, events, state fields, and actions in Terms. Use only evidenced exact Symbols.
6. Router searches paths/names and bounded source contents. Ranking is lexical evidence, not proof of imports, call graphs, or runtime dependencies.
7. Slicer opens every allowed plan candidate before allocating the output budget. It prioritizes distinct patterns and high-value ranges across files.
8. Explicit lifecycle/action terms receive protected coverage: load/save APIs, PlayerAdded/PlayerRemoving/BindToClose, equip/unequip, loaded-state, ownership, rate-limit and save-protection guards.
9. At most one targeted second slice is allowed, only for a documented missing requirement. Reuse the existing plan; never reroute or repeat overlapping extraction.
10. Report eligible files, ranked candidates, selected/opened/matched files, emitted lines, all unranked/unopened/truncated notices, and evidence gaps. Never imply full coverage if a budget was applied.
11. Prefer decisive evidence over arbitrary token caps. Never reduce requested depth just to shrink context.

## One-call command

Codex:
~~~powershell
& "$env:USERPROFILE\.agents\skills\token-optimizer\scripts\Invoke-TokenOptimizer.ps1" -Query "INVENTORY EQUIPMENT CONSUMABLE" -ProjectRoot "C:\path\to\project" -Terms "GetAsync UpdateAsync PlayerAdded PlayerRemoving BindToClose OnServerEvent FireServer equip unequip Owned Equipped loaded cooldown noSave" -MaxSeedFiles 24 -MaxFiles 24 -MaxSnippetsPerFile 16 -ContextLines 1 -MaxLinesPerFile 60 -MaxTotalLines 400
~~~

Claude Code: use the same arguments with `$env:USERPROFILE\.claude\skills\token-optimizer\scripts\Invoke-TokenOptimizer.ps1`. Replace Query and Terms with concepts grounded in the actual task; do not copy Roblox terms into unrelated projects. Use broad adapters only when they materially help.

## Two-stage fallback
Only when exact identifiers need to be selected from plan evidence:
1. Run Invoke-AgentRouter.ps1 once.
2. Read the generated plan once.
3. Run Invoke-ContextSlice.ps1 once with grounded Symbols/Terms.
4. One targeted second slice only if decisive evidence is still absent.

## Scope and safety
- Router ceilings: 100,000 files, 20,000 directories, 8,000 content files, 1 MiB/file, 64 MiB aggregate size budget, 20,000 lines/file.
- Slicer defaults: 24 files, 16 match groups/file, 1 context line, 60 lines/file, 400 total source lines. All selected candidates are inspected before output lines are distributed.
- Source remains read-only. Scripts do not execute project code, edit sources, spawn agents, or regenerate indexes.
- Reject traversal/absolute paths, dependencies, build/cache/generated/backup folders, unsupported extensions, oversized files, and reparse-point paths.
- Common languages: Lua/Luau, Python, JS/TS, Java/Kotlin, C#/F#, Go, Rust, Ruby/PHP, Swift/Scala, C/C++, HTML/CSS, JSON/YAML/TOML/XML, SQL, GraphQL/Proto, shell, PowerShell. Documentation is opt-in.
- Matching is lexical, not AST or semantic analysis.

## Evidence and quality
- Cite exact file paths and line ranges. Separate source-confirmed facts from routing hints and inference.
- Read metrics only from the current terminal output. Never reuse README/EVAL or previous-run metrics as current.
- Provider token counts are reported only when actual telemetry is available. Lines are not tokens.
- Script tests validate routing/extraction behavior, not model intelligence. Do not claim reasoning quality is preserved without a paired same-model, same-reasoning, same-repository evaluation and correctness rubric.
- For analysis tasks, do not edit project source. Keep the final answer complete, evidence-based, and honest about omissions.
