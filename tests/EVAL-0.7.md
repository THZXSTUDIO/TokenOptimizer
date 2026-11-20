# Evaluation — TokenOptimizer UNIVERSAL 0.7

Date: 2026-11-20
Implementation target: Windows PowerShell 5.1, Codex and Claude Code.
Scope: universal project/file-layout routing and bounded multi-language source excerpts. This is a universal-by-project-and-language core; the current implementation is Windows PowerShell, not a cross-platform Linux/macOS release.

## Architecture
- No Graphify snapshot or src directory required.
- Router scans bounded file/directory metadata and ranks project paths by task terms. It reads zero source-content bytes.
- The scanner is a small .NET helper compiled once and cached under %LOCALAPPDATA%\TokenOptimizer\0.7.
- Normal routing includes source/config formats. Markdown/RST/text documents are eligible only when explicitly requested.
- Dependencies, common caches/build outputs, generated folders, backups and reparse points are filtered.
- Slicer reads only paths in the generated plan, rejects traversal/absolute/blocked paths, and emits bounded matching excerpts with language fences.
- The combined entry can route and slice in one command when exact symbols/terms are already known.
- The full task prompt, acceptance criteria, safety constraints and implementation requirements must remain in model context. The routing query is only a file-discovery hint.

## Automated tests
Test suite: tests/Test-TokenOptimizer-0.7.ps1

Latest executed result:
**9 passed | 0 failed** on both Codex and Claude installations.

Coverage:
1. Windows PowerShell 5.1 parser compatibility for router and slicer.
2. TSX, C#, Python and Go discovery in independent project areas.
3. Folder names containing spaces.
4. Default exclusion of node_modules, backup/generated directories and docs.
5. Symbol extraction with language-aware fences.
6. Exact relevance-score ordering before the file budget.
7. Explicit documentation opt-in.
8. Rejection of traversal, absolute, dependency and backup paths, even when inserted manually into a plan.
9. Combined entry route + slice operation.
10. SHA-256 source integrity/read-only behavior.

The nine PASS assertions include the syntax checks, cross-language/exclusion test, snippet test, ranking, docs, malicious path checks, integrated entry, and source integrity. Live language fixtures are TSX, C#, Python and Go. Other extension mappings are present but not individually tested by this fixture suite.

## Live RobloxGraph A/B benchmark
Same local project snapshot.
Same user intent: INVENTORY EQUIPMENT CONSUMABLE LOOT.
Same exact slicer symbols and 55-line output budget.
Same six matching files in the live snippet smoke test.

### Five-run median in a persistent PowerShell session
The scripts were called directly using the PowerShell call operator. The scanner DLL was loaded once and remained available in the session.

| Version | Median route + slice |
|---|---:|
| 0.6 | 1,667 ms |
| 0.7 | 144 ms |

Observed ratio: **11.58x**.
First pair included 0.7's helper-load cost:
- 0.6: 2,650 ms.
- 0.7: 374 ms.

Both slicers were configured with MaxTotalLines=55. The previous live smoke test observed 6 matched files and 55 emitted lines for both versions. This is a local processing speed result, not a general promise for all projects or operating systems.

### Fresh nested PowerShell process comparison
A second five-pair benchmark modeled the old two-launch workflow (one PowerShell process for route, a second for slice) versus the new integrated one-launch entry. Median end-to-end times:
- 0.6 two launches: 7,978 ms.
- 0.7 one launch: 4,318 ms.
- Ratio: **1.85x**.

This is below 2x for that fresh-process workflow. For the measured faster path, invoke the script directly from an already open PowerShell terminal rather than starting another powershell.exe per stage. Keep the warm-session result and cold-process result distinct when reporting performance.

## Token economy and answer quality
The tools enforce file, scan, excerpt and output-line limits and avoid whole-file dumps. This is evidence of bounded context behavior, not a measured model-token reduction percentage.

Actual provider token usage, task correctness, hallucination rate and reasoning quality were not measured. Therefore this evaluation does not prove intelligence unchanged or superior. A publishable quality claim requires paired end-to-end tasks run with the same model/version, reasoning settings, project snapshot and a correctness rubric, while recording actual token usage.

The skill instructions explicitly preserve the full user task and constraints and prohibit dropping decisive excerpts just to meet a token target. If the available evidence is insufficient, the agent must expand the context or report the gap.

## Known limitations
- Current native implementation is Windows PowerShell; do not describe this release as Linux/macOS cross-platform.
- Router matching is based on path and filename terms. It is not semantic search, AST analysis, a compiler, or a dependency graph.
- Slicer matching is lexical and bounded. It does not resolve imports, overloads, runtime references or framework semantics.
- Candidate ranking may omit relevant files when terms are vague or a project exceeds scan limits. Watch the truncated flag and refine queries or raise limits when needed.
- The first run can pay .NET helper compilation/loading overhead. Repeated calls in the same PowerShell process benefit from the already-loaded helper.
- Docs are opt-in; add docs/readme/guide/architecture terms when those files are important.
- The scanner does not read .gitignore rules; use a narrower ProjectRoot in monorepos or generated-heavy repositories.

## Release state
- PowerShell parser passed for all scripts.
- Universal test suite passed 9/9 in both Codex and Claude.
- Full installation trees: 21 files each; zero missing, extra, or SHA-256 mismatches.
- Release archive created and verified: Documents/TokenOptimizer-Universal-0.7.zip.
- 0.6 and 0.5 backups retained separately.
- No project source files were modified by the test suite.
