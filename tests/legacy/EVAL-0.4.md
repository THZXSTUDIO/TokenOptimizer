# Evaluation — TokenOptimizer 0.4

## Regression case
Compact query: AURA DIVINO CLICK POWER

Expected high-priority paths should include relevant Aura, Click, and Power progression modules from the current Graphify snapshot and/or filename fallback.

## Rejection criteria
- Generic request words create unrelated seeds.
- Backup, legacy, disabled, generated, or non-src paths appear.
- A graph edge is presented as proof without source confirmation.
- More than one router invocation or graph snapshot load occurs in the default workflow.
- A trivial one-file task spawns agents.
- More than 3 agents are started by default.
- Agents receive the entire user prompt or duplicate file assignments.
- The router reads source file contents or modifies game source.

## Benchmark record
For each comparable task, record model/reasoning settings, repository snapshot, actual input/output token usage when available, correctness, wall time, number of source files read, tool calls, and agent count.

Do not claim a token reduction from wall time, file counts, report size, or characters/4 alone.
