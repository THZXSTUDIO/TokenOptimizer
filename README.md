# TokenOptimizer

**Version:** 0.7.3  
**Status:** Public preview  
**Platforms:** Windows 10/11 with Windows PowerShell 5.1 or PowerShell 7  
**Agent integrations:** OpenAI Codex and Claude Code

TokenOptimizer is a read-only project router and bounded, coverage-aware source extractor for multi-file software engineering tasks. It helps a coding agent identify a focused set of relevant project files and collect evidence-bearing excerpts before analysis.

It is designed to reduce unnecessary repository-wide reading and repeated file-opening steps without replacing the agent's reasoning, the user's requirements, or normal verification.

> **Important:** TokenOptimizer does not guarantee a fixed token saving, faster model response, or unchanged/improved reasoning quality. Those outcomes depend on the project, task, agent, model, and actual evaluation.

## What it does

1. **Routes a task to candidate files.** Searches paths, filenames, identifiers, and bounded source contents using task-specific terms.
2. **Ranks candidates.** Uses lexical relevance, term coverage, and directory diversity to prioritize likely evidence.
3. **Extracts bounded source excerpts.** Opens permitted candidates and selects relevant line ranges rather than dumping entire files.
4. **Prioritizes important evidence when requested.** Lifecycle, persistence, action, validation, ownership, cooldown, and save-protection patterns can receive higher priority.
5. **Reports coverage boundaries.** Distinguishes eligible, scanned, ranked, selected, opened, and matched files; reports truncation and output-budget limits.
6. **Keeps source files read-only.** Writes routing plans and generated context output under the target project's `TokenOptimizer` directory, not into source files.

## Version 0.7.3 highlights

- Bounded lexical content discovery can find relevant files even when their filenames are generic.
- CamelCase-aware matching recognizes identifiers such as `GetAsync`, `InventoryIcons`, and `EquipmentModels`.
- Candidate ranking uses term coverage and directory diversity.
- Router reporting separates eligible files, ranked candidates, selected candidates, and eligible-but-unranked files.
- The slicer inspects all candidates allowed by `MaxFiles` before distributing the output-line budget.
- Snippet selection favors distinct evidence patterns and relevance-weighted ranges.
- Optional lifecycle/action priorities cover load/save APIs, player lifecycle hooks, equip/unequip branches, loaded-state checks, ownership checks, cooldown/rate-limit checks, and `noSave` protection.
- Default extraction limits: 24 files, 16 match groups per file, 1 context line, 60 lines per file, and 400 total source lines.

See [CHANGELOG.md](CHANGELOG.md) and [tests/EVAL-0.7.3.md](tests/EVAL-0.7.3.md).

## Requirements and compatibility

| Component | Supported target | Notes |
|---|---|---|
| Operating system | Windows 10 / Windows 11 | Native scripts use Windows paths and Windows PowerShell/.NET facilities |
| PowerShell | Windows PowerShell 5.1; PowerShell 7 on Windows | PowerShell 5.1 is the tested baseline |
| .NET helper | .NET Framework compiler support | Windows PowerShell 5.1 provides `Add-Type` |
| Coding agents | OpenAI Codex; Claude Code | The skill instructions provide separate install paths |
| Project languages | Common source/config formats listed below | Language support means lexical recognition, not a full semantic parser |

Common recognized formats include Lua/Luau, Python, JavaScript/TypeScript, Java/Kotlin, C#/F#, Go, Rust, Ruby/PHP, Swift/Scala, C/C++, HTML/CSS, JSON/YAML/TOML/XML, SQL, GraphQL/Proto, shell, and PowerShell.

**Not a native Linux/macOS release.** The project/language discovery logic is intended to be broad, but the current executable implementation is Windows PowerShell. Running it under PowerShell on Linux/macOS is not claimed or tested.

## Installation

### Codex

Copy the `token-optimizer` folder into:

```text
%USERPROFILE%\.agents\skills\token-optimizer
```

The resulting path must contain `SKILL.md` and the `scripts` directory.

### Claude Code

Copy the same folder into:

```text
%USERPROFILE%\.claude\skills\token-optimizer
```

Restart the agent session or reload its skill discovery so the updated instructions are available.

## Usage

For a multi-file task, the agent should preserve the complete user request and use a concise, task-grounded query. Example for a Roblox/Luau inventory task in Codex:

```powershell
& "$env:USERPROFILE\.agents\skills\token-optimizer\scripts\Invoke-TokenOptimizer.ps1" `
  -Query "INVENTORY EQUIPMENT CONSUMABLE" `
  -ProjectRoot "C:\path\to\project" `
  -Terms "GetAsync UpdateAsync PlayerAdded PlayerRemoving BindToClose OnServerEvent FireServer equip unequip Owned Equipped loaded cooldown noSave" `
  -MaxSeedFiles 24 -MaxFiles 24 -MaxSnippetsPerFile 16 `
  -ContextLines 1 -MaxLinesPerFile 60 -MaxTotalLines 400
```

For Claude Code, replace the script path with:

```powershell
"$env:USERPROFILE\.claude\skills\token-optimizer\scripts\Invoke-TokenOptimizer.ps1"
```

Use the same arguments. Replace example terms with concepts and APIs actually relevant to the current task. Do not use Roblox-specific terms for unrelated projects.

### Direct script invocation

Call the PowerShell scripts directly with the call operator (`&`). Do not wrap them in RTK, `rtk run`, `rtk proxy`, nested PowerShell, or `-EncodedCommand`. The installed machine-level RTK instructions include a narrow exception for these scripts.

## How it works - end to end

TokenOptimizer is a preparation layer between a coding task and the agent's source-code investigation. It does not solve the task by itself. It builds a bounded, traceable evidence packet so Codex or Claude Code can focus its context on the files most likely to matter.

### 1. Understand the task and build search signals

The agent keeps the user's full request and turns it into two complementary signal groups:

- **Query concepts:** names of the feature, subsystem, screens, services, modules, or behavior involved. These help identify relevant folders and filenames.
- **Terms and symbols:** concrete identifiers such as functions, events, state fields, API names, and actions. These help find evidence inside source files. Exact symbols should only be supplied when known from project evidence; otherwise use grounded concepts and terms.

For example, an inventory-persistence task might use `inventory`, `equipment`, and `consumables` as concepts, then `GetAsync`, `UpdateAsync`, `PlayerRemoving`, `Owned`, `Equipped`, and `OnServerEvent` as source terms. The agent must adapt these signals to the actual repository rather than copying examples blindly.

### 2. Discover files within fixed safety limits

The router validates the project root, walks eligible directories, and collects file/path metadata. It skips common dependency, build, cache, generated, backup, unsupported, oversized, and reparse-point paths. It then scans eligible source/config content under hard ceilings. Default ceilings are 100,000 filesystem entries, 20,000 directories, 8,000 content files, 1 MiB per file, 64 MiB aggregate content, and 20,000 lines per file.

Content scanning lets the router find code stored in generically named files. Matching understands ordinary text and common identifier styles, including CamelCase, but it is lexical matching - not language parsing.

### 3. Rank likely candidates

Each candidate receives relevance signals from matched task concepts and source terms. The selection pass favors files that cover more requested concepts and avoids spending the entire candidate set in one directory when other directories provide distinct evidence. The goal is a useful spread of likely-relevant files, not a claim that every dependency has been discovered.

The router reports stages separately: eligible files, content-scanned files, ranked candidates, selected candidates, and eligible files that were not ranked. A file can be eligible for scanning without being a strong match for the current query.

### 4. Open candidates and choose evidence ranges

The slicer reads safe, in-project paths from the router plan. It inspects candidates permitted by `MaxFiles` before distributing the final line budget. Within each file, it looks for distinct matching patterns and chooses relevance-weighted line ranges, adding configured context around each match. It reserves a small evidence floor across matched files before allocating remaining lines by relevance. This reduces the chance that one large or highly-scored file consumes the entire output.

When requested by the task, priority patterns help surface important behavior such as data loading/saving, player lifecycle hooks, equip/unequip branches, loaded-state checks, ownership validation, cooldown/rate limiting, and save-protection flags. These are heuristics: a matching line is evidence to inspect, not proof that the whole flow is correct.

### 5. Emit a bounded evidence packet and coverage report

The output contains source excerpts with file paths and line ranges, together with counts for candidates opened and matched, lines emitted, clipping, truncation, and omissions. Default slicer limits are 24 files, 16 match groups per file, one context line, 60 lines per file, and 400 source lines total. Increasing limits may improve context but also increases reading and context cost.

The agent should use excerpts as a map into the repository: verify decisive claims against actual source, follow important references when needed, run appropriate tests separately, and state what was not inspected. It must not describe the packet as complete project coverage when the report shows unranked files or a reached output budget.

### 6. Keep project source unchanged

The scripts do not execute project code, launch agents, run project tests, or edit source files. They write routing plans and generated context under the project's `TokenOptimizer` output directory. The coding agent remains responsible for reasoning, implementation, test execution, and final verification.

### Example workflow

1. User asks for a multi-module bug investigation.
2. Agent extracts task-specific concepts and identifiers without dropping acceptance criteria.
3. TokenOptimizer scans eligible project metadata and bounded source content.
4. Router ranks likely-relevant files and records coverage counts.
5. Slicer opens permitted candidates and emits a relevance-weighted, line-bounded evidence packet.
6. Agent follows the evidence, checks additional source where necessary, makes changes only if requested, and runs normal verification.

For a narrow task where the exact file is already known, skip TokenOptimizer and inspect that file directly. It is intended for multi-file uncertainty, not as an extra step for every question.
## Architecture

### Router

- Validates the project root and rejects reparse-point paths.
- Scans bounded filesystem metadata and eligible source/config content.
- Default ceilings: 100,000 filesystem entries, 20,000 directories, 8,000 content files, 1 MiB per file, 64 MiB aggregate content-size budget, and 20,000 lines per file.
- Excludes common dependency, build, cache, generated, backup, unsafe, and reparse-point paths.
- Uses task concepts and source terms to rank likely candidates.
- Writes a plan and explicit coverage/truncation information under the project's `TokenOptimizer` output directory.

### Slicer

- Reads only safe, in-root paths from the generated plan.
- Opens candidates up to `MaxFiles` before final output-line allocation.
- Selects distinct matching patterns and relevance-weighted source ranges.
- Allocates a minimum evidence floor across matched files, then distributes remaining lines by relevance.
- Emits source excerpts in source order and reports opened/matched files, line counts, clipping, and omissions.

## Safety and design boundaries

- **Read-only source behavior:** the tool does not edit project source files.
- **No project execution:** it does not run project code, project tests, coding agents, or background jobs.
- **Bounded work:** file, scan, content, and output limits prevent unbounded repository dumps.
- **Path validation:** traversal, absolute paths in plans, blocked directories, oversized/unsupported files, and reparse-point paths are rejected.
- **No hidden semantic claims:** matching is lexical; it is not AST parsing, semantic indexing, an import graph, call-graph analysis, compiler validation, or runtime tracing.
- **No token fabrication:** source-line counts are not token counts. Actual provider token usage is reported only if real provider telemetry is available.

Review [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) and [docs/SECURITY.md](docs/SECURITY.md) before deployment in sensitive repositories.

## Tests and evaluation

Run the regression suite from a PowerShell terminal:

```powershell
& "$env:USERPROFILE\.agents\skills\token-optimizer\tests\Test-TokenOptimizer-0.7.ps1"
```

For Claude Code, use the corresponding `.claude\skills` path.

Latest local regression run on 2026-11-20:

- **15 passed, 0 failed**
- Four PowerShell scripts parsed without syntax errors under Windows PowerShell 5.1.
- Coverage includes cross-language discovery fixtures, generic-name content discovery, CamelCase matching, event-noise filtering, candidate ordering, fair line-budget distribution, lifecycle/action evidence, path safety, integrated invocation, and source integrity.

The latest local RobloxGraph smoke test is documented in [tests/EVAL-0.7.3.md](tests/EVAL-0.7.3.md). It reports 90 eligible files, 90 content-scanned files, 19 ranked/selected/opened/matched files, 71 eligible-but-unranked files, and a 400-line output ceiling. Router time was 497 ms, slicer time 5,457 ms, and the full PowerShell process 7.74 s for that specific run.

These are **local script-pipeline measurements**, not a general performance guarantee or an end-to-end model benchmark. A user-reported 0.7.2 Codex timing comparison is historical and not a controlled 0.7.3 A/B test. No provider token telemetry or paired model-answer quality evaluation is available. Do not infer preserved or improved model intelligence from script tests.

## Known limitations

- Lexical matching can miss relevant files when task terms are vague, naming is unusual, or code is abstracted behind unfamiliar patterns.
- Eligible-but-unranked files are not deeply inspected by the slicer.
- The 400-line default output budget can omit lower-priority evidence even after all selected candidates have been opened.
- Language comment and API/action detectors are heuristics.
- The router does not resolve imports, aliases, overloads, framework semantics, or runtime dependencies.
- Repository-specific behavior should be checked against the actual source and the reported coverage notices.

## Repository structure

```text
SKILL.md
scripts/
  Invoke-AgentRouter.ps1
  Invoke-ContextSlice.ps1
  Invoke-TokenOptimizer.ps1
  prepare_context.ps1
references/
  robloxgraph-profile.md
tests/
  Test-TokenOptimizer-0.7.ps1
  EVAL-0.7.3.md
  sample-project/
  legacy/
docs/
  COMPATIBILITY.md
  SECURITY.md
CHANGELOG.md
```

## License

No license has been selected or included in this repository yet. Until the owner adds a license, do not assume permission to redistribute, modify, or use the code under an open-source license.

## Contributing

Bug reports and reproducible test cases are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).
