---
name: github-address-pr-comments
description: Fetch, triage, and address remote GitHub pull request comments. Use when asked to solve PR comments, respond to review feedback, classify which comments are actionable, draft replies and fix plans for user review, and only in a later approved turn post those replies and apply the approved fixes on the branch. Works across Codex, Gemini, Claude Code, and similar agents by keeping the workflow portable and using whatever GitHub integration is available.
---

# GitHub Address PR Comments

## Overview

Fetch all review comments on a PR, analyze each for technical merit, present a classified summary and wait for explicit user approval, fix only those that are reasonable, reply to every comment thread (either confirming a fix or pushing back with technical rationale), and mark fixed threads as resolved.

**Never fix a comment silently. Every thread gets a reply. Never mark a thread resolved without first replying.**

**The analysis and the execution are always two separate turns.** Present the classification plan, then stop and wait for explicit user approval before touching any file or posting any reply.

## Step 0: Determine Tool Availability

Before doing anything, identify which GitHub tools are available. Do this once at the start.

Priority order: GitHub integration tool (MCP server or native tool) > `gh` CLI.

- **GitHub integration tool**: Check for a built-in GitHub capability. If present, verify authentication with a lightweight test call (e.g., fetch the current user or the PR). If that fails with an auth error, treat the tool as unavailable and fall back to `gh`. Note: most GitHub integrations do **not** expose a thread-resolve operation — fall back to `gh api graphql` for that step regardless.
- **gh CLI**: Run `which gh && gh auth status`. If `gh auth status` reports not logged in, stop and ask the user to run `gh auth login` before continuing.

Get `{owner}` and `{repo}` from `git remote get-url origin` if not already known.

| Operation | GitHub integration tool (if available) | gh CLI |
|---|---|---|
| Read PR + comments | Use the PR-reading tool provided | `gh api graphql` with `reviewThreads` query |
| Reply to thread | Use the comment-reply tool provided | `gh api repos/{owner}/{repo}/pulls/comments/{id}/replies -f body="..."` |
| Resolve thread | *(typically not available — use gh CLI)* | `gh api graphql` with `resolveReviewThread` mutation |

## Step 1: Fetch All Review Comments

Retrieve all open (unresolved) review threads on the PR. For each thread collect:

- Thread/comment ID (both numeric `databaseId` and GraphQL `node_id`)
- File path and line number
- Comment body
- Author
- Whether already resolved

Paginate `reviewThreads` until `pageInfo.hasNextPage` is false. If a thread's `comments` page also has `hasNextPage`, paginate that too before deciding which thread ID to resolve.

## Step 2: Analyze Each Comment

For every comment, classify it before acting. Do not fix and reply in the same pass.

**Reasonable — fix it:**
- Points out a genuine bug, logic error, or incorrect behavior
- Highlights a violation of stated project conventions (project instructions file, existing patterns)
- Identifies a missing edge case that could actually occur
- Flags a security concern

**Unreasonable — push back:**
- Pure stylistic preference with no stated basis
- Request contradicts existing codebase conventions or project instructions
- Based on a misreading of the code — reviewer is factually wrong
- Out of scope for this PR's stated purpose
- Already addressed elsewhere in the PR

When in doubt, default to fixing. Only push back when you can articulate a concrete technical reason.

Read `references/comment-triage.md` if the distinction is unclear.

## HARD STOP — Present Analysis and Wait for Approval

**This step is mandatory and cannot be skipped.**

After classifying all comments, present a summary in this format:

```
## Review Comment Analysis

**Will fix (N):**
- [file:line] <comment summary> — <one-line reason it's valid>
- ...

**Will push back (N):**
- [file:line] <comment summary> — <one-line reason it's unreasonable>
- ...

**Already resolved / not applicable (N):**
- ...

Ready to proceed. Awaiting your approval.
```

Then **STOP completely.** Do not touch any file. Do not post any reply. End your response and wait.

Only continue if the user explicitly approves (e.g. "yes", "go ahead", "looks good"). If the user asks to reclassify any comment, update the plan and stop again — do not proceed.

**There is no implicit approval.** Prior conversation context or urgency are not substitutes for explicit confirmation in the current turn.

## Step 3: Fix Reasonable Comments

Make the actual code (or config) changes. Group changes by file. Do not commit yet.

After each fix, note what changed and which comment it addresses — you will use this in the reply.

## Step 4: Reply to Every Thread

Reply to **every** open thread, even ones where no change was made.

**For fixed comments:**
```
Fixed in <file>:<line>. <One sentence explaining what changed and why>.
```

**For pushed-back comments:**
```
<State what the comment asked for.> <Concrete technical reason why the current approach is correct or preferable, citing code or project conventions.> <Optional: offer a compromise if any>.
```

Keep replies concise and factual. Avoid defensive or dismissive tone.

Prefer a direct reply on the original PR review comment thread when the platform supports threaded replies. If the target item cannot receive a direct threaded reply, post a normal follow-up comment that quotes enough context to make the mapping obvious.

## Step 5: Resolve Fixed Threads

After replying, mark each fixed thread as resolved using the GraphQL mutation:

```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "<thread_node_id>"}) {
      thread { id isResolved }
    }
  }
'
```

Do **not** resolve threads where you pushed back — leave those open for the reviewer to respond.

## Step 6: Commit the Fixes

After all replies are posted and fixed threads are resolved, commit the code changes. Use the `git-plan-commits` skill.

## Portability Notes

- Prefer this order of retrieval tools: GitHub MCP/integration → `gh` CLI → GitHub API directly.
- Keep the workflow the same even if the integration changes.
- If no GitHub access method is available, report the blocker clearly instead of guessing about unseen comments.

## Common Mistakes

| Mistake | Correct behavior |
|---|---|
| Fixing everything without analysis | Classify first, fix only reasonable ones |
| Replying without fixing | Fix code first, then reply |
| Forgetting to reply to pushed-back threads | Every thread gets a reply |
| Resolving threads you pushed back on | Only resolve threads you actually fixed |
| Using integration tool for resolving | GitHub integration tools rarely expose resolve — use `gh api graphql` |
| Skipping thread node IDs | GraphQL needs `node_id`, not numeric ID |
| Resolving before replying | Reply first, then resolve |

## Guardrails

- Do not post unrevised draft replies.
- Keep reply-to-comment mapping exact; never answer the wrong thread.
- If a comment is ambiguous, draft a clarifying reply instead of inventing intent.
- Do not push, merge, or mark threads resolved unless the user explicitly asks.
