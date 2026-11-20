# Evaluation — TokenOptimizer 0.5

## Automated regression suite
Run:
~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\token-optimizer\tests\Test-TokenOptimizer-0.5.ps1"
~~~

Latest result: **10 passed | 0 failed** on Windows PowerShell 5.1.

Coverage:
1. PowerShell 5.1 syntax compatibility.
2. Accent normalization, aliases, and CamelCase handling.
3. Filename fallback for a current Lua file missing from AST metadata.
4. One-hop-only graph expansion; no recursive neighbor traversal.
5. Rejection of src/../ traversal, stale source paths, legacy/backup folders, and identifier-boundary false positives.
6. UI/audio noise filtering, with explicit UI/audio intent exception.
7. Optional Canvas JSON validity.
8. Empty/generic/no-match query handling.
9. Malformed JSON, invalid Graphify schema, and duplicate node-ID rejection.
10. Explicit warning when fallback scan limits are reached.
11. SHA256 source integrity before/after routing (game source remains unchanged).

## Live routing smoke test
Query: AURA DIVINO CLICK POWER

Latest observed result:
- Graph: 912 nodes / 1,733 links.
- Seeds: 5 | One-hop neighbors: 3 | Domains: 3.
- Router elapsed: approximately 1.05 seconds.
- Filename fallback: 170 files / 38 directories; not truncated.
- Source contents read by router: 0.
- Expected Aura, Click, and Power paths selected; no irrelevant UI/audio file selected.

Timing varies by cache and machine state. Compare multiple warm runs before attributing a speed difference.

## End-to-end benchmark (not yet established by router tests)
For each identical task, record:
- Model/version and reasoning setting.
- Exact task and repository snapshot.
- Actual input/output/cached tokens from agent usage telemetry.
- Number of source files opened and total lines read.
- Agent/subagent calls and duplicate assignments.
- Wall-clock time.
- Correctness against a predefined checklist.

Do not claim actual token savings, preserved/improved intelligence, or faster end-to-end model responses from routing tests alone.
