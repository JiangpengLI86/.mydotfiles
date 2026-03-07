# Commit Message Heuristics

Use this file when commit boundaries or message quality are unclear.

## Split Heuristics

- Keep one commit per reviewer-friendly intention.
- Separate mechanical rename or formatting churn from behavior changes when that improves readability.
- Keep tests with the code they validate unless the repo has a strong reason to stage them separately.
- Keep generated lockfiles or snapshots with the change that requires them, unless they hide unrelated upgrades.

## Title Heuristics

- Prefer an imperative verb: `fix`, `add`, `remove`, `refactor`, `document`, `test`.
- Name the affected area when possible.
- Keep the title specific enough that it still makes sense in `git log --oneline`.

Good:
- `fix tmux bootstrap on hosts without libevent`
- `document non-sudo setup prerequisites`
- `refactor bashrc managed block rendering`

Weak:
- `update config`
- `more changes`
- `fix issue`

## Body Heuristics

Add a body only when it increases future understanding. Useful body content includes:

- Why the change was needed.
- What constraint or edge case drove the implementation.
- What tradeoff remains.

Keep the body factual. Avoid repeating obvious diff details line by line.

## Signing Rule

- Respect the repository or user default for `commit.gpgsign`; do not override it with `--no-gpg-sign`.
- If signing is disabled by default, commit normally.
- If signing is enabled by default, try the commit with the default signing behavior intact.
- If signing triggers an interactive GPG or pinentry prompt the agent cannot complete, cancel the blocked commit and provide the exact commit command for the user to run manually.
- Never ask the user to paste a GPG password, passphrase, or private-key secret into chat.
