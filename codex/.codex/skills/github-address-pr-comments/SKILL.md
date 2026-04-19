---
name: github-address-pr-comments
description: Fetch, triage, and address remote GitHub pull request comments. Use when asked to solve PR comments, respond to review feedback, classify which comments are actionable, draft replies and fix plans for user review, and only in a later approved turn post those replies and apply the approved fixes on the branch. Works across Codex, Gemini, Claude Code, and similar agents by keeping the workflow portable and using whatever GitHub integration is available.
---

# GitHub Address PR Comments

## Overview

Collect remote PR feedback, decide which comments deserve action, draft replies, and prepare fix plans before any reply is posted or code is changed. The drafting pass must end after printing the proposed replies and fix plans so the user can approve or request edits in a later turn. Prefer a GitHub MCP server when available, and fall back to `gh` or the GitHub API when needed.

## Workflow

1. Gather the full review context from the remote.
   - Identify the repository, pull request number, and current working branch.
   - Fetch unresolved review comments and discussion comments that the user likely means by "PR comments".
   - Normalize each item with comment id or thread id, author, file and line when present, timestamp, status, and body text.
   - Ignore clearly resolved or purely conversational comments unless the user asks to revisit them.

2. Identify the actionable comments.
   - Treat comments as actionable when they request a concrete code, docs, test, or behavior change, or ask a question that must be answered for review progress.
   - Skip duplicates, resolved threads, and comments that only acknowledge previous work unless the user wants a full audit.
   - Read `references/comment-triage.md` if the distinction is unclear.

3. Judge whether each actionable comment is reasonable.
   - Mark `reasonable` when the request is technically sound, aligned with the codebase, and worth adopting.
   - Mark `not reasonable` when the request is incorrect, stale, contradictory, too broad for the PR, or better solved another way.
   - Record the reason for the judgment so the user can review it.

4. Draft replies before posting anything.
   - Draft a reply for every actionable comment.
   - For reasonable comments, acknowledge the point and summarize the planned or completed fix.
   - For not reasonable comments, explain the disagreement respectfully and propose an alternative or supporting evidence when possible.
   - Do not post replies yet.

5. Create a fix plan for each reasonable comment.
   - Identify the files, tests, and sequencing required to address the feedback.
   - Call out any comments that need clarification before code should change.
   - Do not implement the fix yet.

6. Present the review package to the user and stop.
   - List each actionable comment with:
     - short context
     - reasonableness judgment
     - draft reply
     - fix plan, if applicable
   - End the current turn after printing this package.
   - Wait for a later user message to either approve the package or request modifications.
   - If the user requests changes, revise the draft replies and plans and stop again.
   - Do not post replies or modify code before the user explicitly approves in a later turn.

7. Execute after user approval.
   - Post the approved replies to the correct comments or threads.
   - Prefer a direct reply on the original PR review comment thread when the platform supports threaded replies.
   - If the target item cannot receive a direct threaded reply, post a normal follow-up comment that quotes enough context to make the mapping obvious.
   - Then apply the approved fixes on the branch.
   - Run targeted verification when feasible.
   - Summarize which replies were posted, which fixes were applied, and what remains open.

## Portability Notes

- Prefer this order of retrieval tools:
  1. GitHub MCP or equivalent first-class integration.
  2. `gh` CLI commands or GitHub API calls.
  3. Browser/manual links only if automation is unavailable.
- Prefer this order of reply targets:
  1. Reply directly to the original review comment or review thread.
  2. Reply to the exact PR comment when direct replies are supported for that comment type.
  3. Fall back to a quoted non-thread reply only when GitHub does not support direct replies for that target.
- Keep the workflow the same even if the integration changes.
- If no GitHub access method is available, report the blocker clearly instead of guessing about unseen comments.

## Guardrails

- Do not post unrevised draft replies.
- Keep reply-to-comment mapping exact; never answer the wrong thread.
- The first drafting pass must end after showing the user the proposed replies and fix plans.
- If a comment is ambiguous, draft a clarifying reply instead of inventing intent.
- Do not push, merge, or mark threads resolved unless the user explicitly asks.
