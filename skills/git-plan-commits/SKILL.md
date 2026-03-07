---
name: git-plan-commits
description: Plan and create local git commits from an existing worktree. Use when asked to commit changes, split a mixed diff into readable commits, draft commit titles and bodies, or respect the repo's default GPG signing behavior while committing. Works across Codex, Gemini, Claude Code, and similar agents because it relies on portable git workflow rather than product-specific features.
---

# Git Plan Commits

## Overview

Plan clean commit boundaries, draft strong commit messages, and create local commits without pushing. Keep the process tool-agnostic: prefer plain `git` commands, and treat richer editor or agent integrations as optional helpers.

## Workflow

1. Inspect the current worktree before deciding anything.
   - Read the unstaged and staged state separately.
   - Review enough diff context to understand intent, generated files, and unrelated edits.
   - If the repo already contains unrelated user changes, exclude them or ask before including them.

2. Decide whether the diff should be split.
   - Split when there are clearly different goals such as bug fix vs refactor, code vs docs, or feature work vs generated lockfile updates.
   - Keep files together when they must land atomically to keep the tree buildable or understandable.
   - Avoid over-splitting trivial edits into noisy micro-commits.
   - If the split is ambiguous, risky, or depends on user preference, show the proposed commit plan before committing.
   - Read `references/commit-messages.md` for commit boundary heuristics and message examples.

3. Draft the commit title and body for each planned commit.
   - Use a short imperative title that describes the change, not the process.
   - Add a body only when it helps future readers understand why the change exists, what constraints shaped it, or what follow-up remains.
   - Avoid vague titles such as `update files`, `fix stuff`, or `misc changes`.

4. Check the repository's signing defaults before committing.
   - Inspect inherited git config for `commit.gpgsign`.
   - Use `git commit --signoff` by default so the created commits include the user's sign-off trailer.
   - If signing is not enabled by default, proceed normally with `git commit --signoff`.
   - If signing is enabled by default, keep the default signing behavior and try `git commit --signoff` without forcing `--no-gpg-sign`.
   - If commit signing prompts for a GPG password or requires an interactive pinentry flow the agent cannot complete, cancel the blocked `git commit` process first, then print the exact `git commit --signoff ...` command for the user to run manually.
   - Never ask the user to paste a GPG password, passphrase, or private-key secret into chat.
   - Do not force `-S` when the repo does not already sign by default.

5. Create the commits in reviewable order.
   - Stage only the files or hunks for the current commit.
   - Re-read the staged diff before each commit.
   - Prefer an order where each commit is independently understandable and, when realistic, buildable.
   - If the user asked only for a plan or draft messages, stop before running `git commit`.

6. Stop after local commit creation.
   - Never push automatically.
   - Summarize the created commits, any excluded files, and any follow-up the user may still want.

## Output Format

- For a multi-commit result, present a short list before execution when the split is not obvious:
  - commit title
  - one-line scope summary
  - whether a body is needed
  - whether repo-default GPG signing is expected to run or a manual commit command may be needed
- After execution, report:
  - created commit titles in order
  - whether repo-default GPG signing was used or the blocked commit was canceled and the manual command was handed off to the user
  - confirmation that nothing was pushed

## Guardrails

- Do not hide unrelated work by bundling it into a convenient commit.
- Do not rewrite the user's intended history unless the split improves readability or reviewability.
- Call out suspicious generated artifacts, vendored files, or local-only changes before committing them.
- Leave pushing, tagging, rebasing, and history rewriting to explicit user requests.
