# TokenOptimizer 0.7.3

**Release date:** 2026-11-20  
**Release type:** Feature and coverage update  
**Compatibility:** Windows 10/11, Windows PowerShell 5.1 baseline; Codex and Claude Code skill integrations

## Highlights

- Adds bounded lexical content discovery in addition to path and filename matching.
- Finds relevant source files even when their names are generic.
- Improves CamelCase identifier matching.
- Ranks candidates using term coverage and directory diversity.
- Reports eligible, scanned, ranked, selected, opened, matched, and unranked file counts separately.
- Inspects all allowed candidates before distributing the bounded output-line budget.
- Selects distinct, relevance-weighted excerpts.
- Prioritizes lifecycle and safety evidence when those patterns are requested.
- Expands the regression suite to 15 checks.

## How the workflow works

1. The agent turns the user's task into focused subsystem concepts and source-level terms while preserving the full request.
2. The router validates the project root and discovers eligible paths and source/config content under fixed file-count, size, and line ceilings.
3. A lexical ranking pass scores candidates using task-term coverage and directory diversity; it reports eligible, scanned, ranked, selected, and unranked counts separately.
4. The slicer opens safe candidates allowed by `MaxFiles`, selects distinct relevance-weighted line ranges, and distributes a bounded output budget across matched files.
5. The agent uses excerpts as navigational evidence, checks decisive source directly, and performs tests/verification independently.

The matcher does not build an AST, import graph, call graph, or runtime trace. Reaching a file or line budget can leave relevant evidence out; preserve the report's omissions and coverage counters in the final analysis.
## Validation

Latest Windows PowerShell 5.1 regression run:

**15 passed | 0 failed**

The four PowerShell scripts parsed without syntax errors. The final ZIP was extracted into a clean verification directory and the same 15-check suite passed from the extracted archive.

## Latest local smoke test

The 2026-11-20 RobloxGraph run reported:

- 90 eligible files; all 90 content-scanned.
- 19 candidates ranked, selected, opened, and matched.
- 71 eligible files not ranked by that query/term set.
- No metadata or content scan truncation.
- 400 source lines emitted, reaching the configured output ceiling.
- Router: 497 ms.
- Slicer: 5,457 ms.
- Full PowerShell process: 7.74 s.

These are measurements from one local script-pipeline run, not a general speed guarantee or an end-to-end AI-agent benchmark.

## Claims deliberately not made

- No exact token-saving percentage: provider token telemetry was unavailable.
- No claim that model intelligence or answer quality is unchanged or improved: a paired same-model evaluation has not been completed.
- No claim of complete semantic project coverage: matching is lexical, 71 eligible files were not ranked in the smoke test, and the 400-line output ceiling applied.
- No native Linux/macOS support claim: the current implementation is Windows PowerShell.

## Included files

See README.md for installation, usage, architecture, compatibility, safety boundaries, and known limitations. See CHANGELOG.md for version history and tests/EVAL-0.7.3.md for detailed measurements.
