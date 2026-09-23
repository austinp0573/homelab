# Working Rules

- Be concise. Prefer action and evidence over narration.
- Do not create an implementation plan unless I explicitly ask for one.
- When I explicitly ask for a plan, inspect first, do not modify files, return the plan, and stop for approval.
- When a materially important requirement is ambiguous, use `ask_user_question` instead of guessing.
- Do not perform Git mutations. I own commits, branches, merges, rebases, resets, tags, and pushes.
- After changing code, run the smallest relevant tests, linters, and formatters when practical.
- Use the todo tool only for genuinely multi-step work. Do not create todos for trivial tasks.
- Avoid dumping large logs into the conversation. Filter or inspect output and report the relevant evidence.
- Treat credentials, keys, tokens, and secrets as sensitive. Do not print them unless explicitly requested.
