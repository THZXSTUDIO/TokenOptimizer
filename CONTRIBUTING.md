# Contributing

Thanks for helping improve TokenOptimizer.

## Before opening an issue

Include:
- Windows version and PowerShell version.
- Agent integration (Codex or Claude Code).
- TokenOptimizer version.
- Minimal reproduction steps.
- Relevant command arguments with private paths and secrets removed.
- Expected behavior and actual behavior.
- Relevant output notices, including truncation and coverage counts.

Never include API keys, access tokens, credentials, private source code, or personal data.

## Pull requests

- Keep changes focused and explain the problem they solve.
- Preserve the read-only source behavior.
- Preserve bounded scanning and extraction.
- Do not weaken path validation to improve recall.
- Add or update regression fixtures for behavior changes.
- Run `tests/Test-TokenOptimizer-0.7.ps1` under Windows PowerShell 5.1.
- Update CHANGELOG and evaluation notes when behavior or measurements change.
- Distinguish synthetic regression results from real-project smoke tests and end-to-end agent benchmarks.

## Performance and quality claims

Do not claim exact token savings from line counts. Do not claim model reasoning is unchanged or improved without paired evaluations using the same model, reasoning settings, repository snapshot, task set, and correctness rubric.
