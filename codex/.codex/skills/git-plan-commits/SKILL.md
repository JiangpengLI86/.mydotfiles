---
name: git-plan-commits
description: Plan and create local git commits from an existing worktree. Use when asked to commit changes, split a mixed diff into readable commits, draft commit titles and bodies, or respect the repo's default GPG signing behavior while committing. Works across Codex, Gemini, Claude Code, and similar agents because it relies on portable git workflow rather than product-specific features.
---

# Git Plan Commits

## Overview

Inspect the current git worktree, decide whether the changes should be committed as one commit or split into several, and draft clear commit titles and bodies before creating any commit. Prefer logically isolated commits even when that requires splitting changes within a single file by hunk.

**The plan and the execution are always two separate turns.** Present the plan, then stop and wait for explicit user approval before staging or committing anything.

## Workflow

### 1. Inspect the worktree

Start by reading the current repository state before proposing any commit structure.

- Check `git status --short`.
- Review diffs with enough granularity to distinguish independent changes.
- Look for separable concerns: refactors mixed with behavior changes, formatting mixed with logic, docs mixed with code, or unrelated fixes bundled together.
- Consider split points inside a single file, not just at file boundaries.
- If the repo already contains unrelated user changes, exclude them or ask before including them.

### 2. Build a commit plan first

**Do not create commits, stage files, or run any git-modifying command in the same turn where the user first asks to commit changes.** This rule holds even if the conversation is long and prior steps already analyzed the changes. The plan turn and the execution turn must always be separate.

Instead, print a commit plan for the user that includes:

- whether the changes should stay in one commit or be split
- the rationale for each split
- the files or hunks that belong in each proposed commit
- a concise commit title for each commit
- a fuller commit message body when helpful

Read `references/commit-messages.md` for commit boundary heuristics and message examples.

When the split is not obvious, prefer clearer history over fewer commits.

### 3. Present the plan clearly

Present findings in a compact, actionable format. Include enough detail that the user can approve or adjust the plan quickly.

Always remind the user prominently to unlock the GPG signing key before the actual commit step if commit signing may be enabled:

`IMPORTANT: Unlock the GPG signing key before I create the commits, or git commit may hang waiting for the passphrase.`

### 4. HARD STOP — Wait for explicit user confirmation

**This step is mandatory and cannot be skipped, even mid-conversation or after extended context.**

After presenting the plan:

- **STOP completely.** Do not stage files. Do not run git commands. Do not proceed.
- End your response. Wait for the user's next message.
- Only continue if the user explicitly approves (e.g. "yes", "approve", "go ahead", "looks good").
- If the user requests changes, revise the plan and stop again — do not commit.

**There is no implicit approval.** Prior conversation context, previous approvals, or urgency are not substitutes for explicit confirmation in the current turn. If you are unsure whether the user has approved, ask — do not proceed.

### 5. Commit after approval

After approval:

- Check whether the repository has a pre-commit script or linter convention (look for `pre-commit` config, Makefile targets, or project-specific instructions). If one exists, run it before staging. If it changes files, review the resulting diff and restage the intended commit contents before committing.
- If a pre-commit check fails, stop and report the failures instead of attempting `git commit`.
- Stage only the files or hunks for the current commit.
- Re-read the staged diff before each commit.
- Prefer an order where each commit is independently understandable and, when realistic, buildable.
- Always use `git commit --signoff` so commits include the user's sign-off trailer.
- Inspect inherited git config for `commit.gpgsign`. If signing is enabled by default, keep it. If signing prompts for a GPG passphrase the agent cannot enter, cancel the blocked commit and hand off the exact `git commit --signoff ...` command for the user to run manually.
- Never ask the user to paste a GPG password or passphrase into chat.
- Do NOT add a `Co-authored-by` trailer for any AI tool.

When a single file must be split across multiple commits, stage only the intended hunks for each commit. Prefer deterministic patch-based staging over interactive prompts.

### 6. Stop after local commit creation

- Never push automatically.
- Summarize the created commits, any excluded files, and any follow-up the user may still want.

## Commit Planning Heuristics

- Keep one logical change per commit.
- Separate pure formatting from semantic changes when practical.
- Separate renames or mechanical refactors from behavior changes when practical.
- Separate documentation updates from code changes unless the docs are inseparable from the code change.
- Prefer a single commit when the changes are tightly coupled and splitting would make history harder to understand.
- Split within one file when unrelated hunks represent different concerns.

## Commit Message Guidance

- Write commit titles in imperative mood.
- Keep the title concise and specific.
- Use the body to explain intent, scope, and any important tradeoffs.
- Avoid vague titles such as `update code` or `fix stuff`.

## Failure Handling

- If `git commit` hangs, suspect GPG passphrase or pinentry issues first.
- Tell the user that the most likely cause is a locked GPG signing key.
- Resume only after the user unlocks the key or confirms commit signing should be bypassed.
- Do not silently fall back to unsigned or altered commit behavior without user approval.

## Guardrails

- Do not hide unrelated work by bundling it into a convenient commit.
- Do not rewrite the user's intended history unless the split improves readability or reviewability.
- Call out suspicious generated artifacts, vendored files, or local-only changes before committing them.
- Leave pushing, tagging, rebasing, and history rewriting to explicit user requests.
