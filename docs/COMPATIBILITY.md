# Compatibility

## Supported environment

The current release is a Windows implementation.

| Target | Status |
|---|---|
| Windows 10 | Supported target |
| Windows 11 | Supported target |
| Windows PowerShell 5.1 | Tested baseline |
| PowerShell 7 on Windows | Supported target; verify in the target environment |
| PowerShell on Linux/macOS | Not supported or validated in this release |
| OpenAI Codex | Skill integration documented |
| Claude Code | Skill integration documented |

The router uses Windows PowerShell/.NET functionality and Windows path behavior. Do not describe this release as cross-platform merely because it recognizes source files from many languages.

## Language and file-format recognition

The universal router recognizes common code and configuration formats, including:

- Lua and Luau
- Python
- JavaScript and TypeScript
- Java and Kotlin
- C# and F#
- Go and Rust
- Ruby and PHP
- Swift and Scala
- C and C++
- HTML and CSS
- JSON, YAML, TOML, and XML
- SQL, GraphQL, and Protocol Buffers
- Shell and PowerShell

This list describes extension/content recognition and lexical matching. It does not mean every language has an AST parser, compiler integration, semantic index, or dedicated regression fixture.

## Runtime requirements

- A Windows PowerShell 5.1 or PowerShell 7 terminal.
- .NET Framework compiler support for the cached scanner helper. Windows PowerShell 5.1 provides `Add-Type`.
- Read access to the target project.
- Correct `-ProjectRoot` argument.
- The agent must be able to invoke PowerShell scripts from its terminal.

## Agent installation paths

Codex:
`%USERPROFILE%\.agents\skills\token-optimizer`

Claude Code:
`%USERPROFILE%\.claude\skills\token-optimizer`

Install the complete folder, preserving `SKILL.md`, `scripts`, `references`, and `tests`.

## Not guaranteed

- Linux/macOS native compatibility.
- AST or semantic analysis.
- Complete project coverage when scan/output limits apply.
- Exact token savings or a fixed speedup.
- Unchanged or improved model reasoning quality.
