# Optional Roblox adapter profile

The TokenOptimizer core is language- and project-layout agnostic. This profile is an optional domain reminder for Roblox/Luau projects, not a required configuration.

## Before routing
- Pass the actual Roblox project folder as -ProjectRoot.
- Do not assume a folder named src; the project may have another Rojo mapping or directory layout.
- Graphify may be used separately as a navigation source when available, but the universal core does not require it and filename matches are not proof of runtime dependencies.

## Roblox-specific evidence to validate
When tracing a gameplay feature, inspect only what is relevant:
- The script/module that owns the authoritative value or behavior.
- Event origin and direction: RemoteEvent, RemoteFunction, BindableEvent, ProximityPrompt, Tool, attributes or values.
- Server validation and authority.
- Client consumer/UI and replication.
- Configuration, player data and persistence.
- Direct module calls and producer -> event/state -> consumer paths.

Do not treat names such as Click, Clicks, ClickValue and ClickPower as equivalent without confirming their semantics in source.

## Optional snippet pattern
Use -IncludeRobloxEdges only when remote events, bindables, player lifecycle or DataStore operations matter. It is a lexical hint, not a parser or security audit.
