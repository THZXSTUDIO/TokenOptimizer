# Security and data handling

## Intended behavior

TokenOptimizer is designed as a local, read-only source-routing and excerpt-extraction utility.

- It reads project paths and eligible source/config files within the supplied project root.
- It does not execute project code, project tests, agents, or background jobs.
- It does not modify source files.
- It writes routing plans and extracted context output under a `TokenOptimizer` directory in the target project.
- It applies bounds to filesystem traversal, content discovery, candidate count, and emitted source lines.

## Path and scan safeguards

The scripts include checks intended to reject path traversal, absolute paths in routing plans, blocked dependency/build/cache/generated/backup paths, unsupported or oversized files, and reparse-point paths. These are defense-in-depth safeguards, not a formal security audit.

## Sensitive repositories

Extracted excerpts may contain proprietary code, credentials accidentally embedded in source, personal data, or other confidential information. The tool is not a secret scanner and does not guarantee redaction.

Before sending generated context to an AI provider:
1. Follow your organization's data-handling and AI-use policies.
2. Inspect the generated output for secrets and sensitive data.
3. Restrict `ProjectRoot` to the smallest relevant project directory.
4. Review the selected file list and coverage notices.
5. Do not assume lexical relevance means a file is safe to disclose.

## Reporting vulnerabilities

Do not publish exploit details or credentials in an issue. Contact the repository owner privately through an appropriate GitHub security-reporting channel if one is enabled. If private reporting is unavailable, open a minimal issue without sensitive payloads.

## Limitations

This project has not been represented as independently security-audited. Lexical path and content heuristics do not replace operating-system permissions, endpoint security, secret scanning, code review, or sandboxing.
