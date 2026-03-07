---
name: git-plan-commits
description: Plan and create local git commits from an existing worktree. Use when asked to commit changes, split a mixed diff into readable commits, draft commit titles and bodies, or decide whether the repo's default GPG signing should be used or bypassed. Works across Codex, Gemini, Claude Code, and similar agents because it relies on portable git workflow rather than product-specific features.
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
   - If signing is not enabled by default, use plain `git commit`.
   - If signing is enabled by default, use `git commit --no-gpg-sign` unless the user explicitly asked for signed commits.
   - If the user explicitly asked for signed commits and the key needs a password, ask for the password instead of silently bypassing signing.
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
  - whether signing will be bypassed with `--no-gpg-sign`
- After execution, report:
  - created commit titles in order
  - whether signing was preserved or bypassed
  - confirmation that nothing was pushed

## Guardrails

- Do not hide unrelated work by bundling it into a convenient commit.
- Do not rewrite the user's intended history unless the split improves readability or reviewability.
- Call out suspicious generated artifacts, vendored files, or local-only changes before committing them.
- Leave pushing, tagging, rebasing, and history rewriting to explicit user requests.
