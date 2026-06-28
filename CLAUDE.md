<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# Operational guidance

- Testbenches that take longer than 30s to execute are not viable. Find another way that accomplishes the same thing
- This project uses REUSE. All files must have signature
- We must strive for incremental progress
- Any code that you provide should be validated and succeed at thorough simulation
- Never ever execute a command which results in changing the staged contents of the git repo
- Never ever commit to the git repo
- When making changes, changes as few lines as possible.
    - lines in new files count as changed lines
- Don't re-invent the wheel, ever.
- Use guidance from AGENTS.md
