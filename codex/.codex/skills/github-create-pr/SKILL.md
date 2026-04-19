---
name: github-create-pr
description: Use when asked to create a pull request from an existing local branch, publish work for review on GitHub, or share ready changes from a feature branch, including organization-owned and fork-based repositories.
---

# GitHub Create PR

## Overview

Determine the correct head branch, push remote, and PR target repository, draft a PR title and description, and stop for explicit user approval before pushing or creating the pull request.

**The plan and the execution are always two separate turns.** Present the PR draft, then stop and wait for explicit user approval before pushing or opening the PR.

## Step 0: Determine Tool Availability

Before doing anything, identify which GitHub tools are available. Do this once at the start.

Priority order: GitHub integration tool (MCP server or native tool) > `gh` CLI.

- **GitHub integration tool**: Check for a built-in GitHub capability. If present, verify authentication with a lightweight test call (e.g., fetch the current user). If that fails with an auth error, treat the tool as unavailable and fall back to `gh`.
- **gh CLI**: Run `which gh && gh auth status`. If `gh auth status` reports not logged in, stop and ask the user to run `gh auth login` before continuing.

| Operation | GitHub integration tool (if available) | gh CLI |
|---|---|---|
| Detect current user | Use the user-info tool provided | `gh api user --jq '.login'` |
| Create PR | Use the PR-creation tool provided | `gh pr create ...` |
| Push branch | *(not available — use git)* | `git push -u <head-remote> <branch>` |

## Step 1: Gather Repository and Branch Context

Collect the information needed to build the PR before writing anything.

```bash
# Current branch
git rev-parse --abbrev-ref HEAD

# All remotes
git remote -v

# URLs for likely PR remotes
git remote get-url origin
git remote get-url upstream   # if present

# Branch tracking remote, if configured
git config --get branch.<branch>.remote

# Default branch of the target repo
gh repo view <base-owner>/<base-repo> --json defaultBranchRef --jq '.defaultBranchRef.name'
# or, if using GitHub integration tool: inspect target repo metadata

# Commits that will appear in the PR (not yet on base branch)
git log --oneline <base-remote>/<default-branch>..<branch>
```

Parse `owner` and `repo` from remote URLs. The remote URL may be:

- `https://github.com/<owner>/<repo>.git`
- `git@github.com:<owner>/<repo>.git`

Determine these values explicitly before drafting:

- `branch`: the local branch that will become the PR head
- `head-remote`: the remote that will receive the branch push
- `head-owner`/`head-repo`: parsed from `head-remote`
- `base-remote`: the repository the PR targets
- `base-owner`/`base-repo`: parsed from `base-remote`
- `default-branch`: the base branch in `base-owner`/`base-repo`

Choose them with these rules:

1. If the user explicitly names the PR target repo or base branch, use that.
2. Otherwise, use the branch's tracking remote as `head-remote` when available; if there is no tracking remote yet, default `head-remote` to `origin`.
3. If an `upstream` remote exists and differs from `head-remote`, treat `upstream` as `base-remote` by default. This is the common fork workflow: push to the fork, open the PR against `upstream`.
4. If there is no distinct `upstream`, set `base-remote` equal to `head-remote`.

**Important — organization-owned repositories:** The `owner` segment may be an organization, not the authenticated user. Do not assume the repo owner matches the authenticated GitHub user.

**Important — fork-based repositories:** The PR head repo and base repo may be different. Keep them separate throughout the workflow. Do not derive the PR target from the push remote unless they are confirmed to be the same repository.

If the remotes are ambiguous or missing, ask the user to confirm the PR target before continuing.

## Step 2: Ensure a Feature Branch Exists

This skill never pushes the default branch directly.

- If `branch` is already a feature branch, keep it.
- If `branch` matches the repo's default branch (for example `main` or `master`), choose a feature branch name before presenting the draft.
- Present that proposed branch name in the plan turn and wait for approval before creating it.

Recommended naming:

- `feat/<short-description>`
- `fix/<short-description>`
- `docs/<short-description>`

After approval, if a new branch is needed:

```bash
git switch -c <branch>
```

## Step 3: Draft the PR Title and Description

Read the commits that will be included in the PR and any relevant context (branch name, related issue references, diff summary) to draft a pull request.

**Title:**
- Imperative mood, concise, specific.
- Summarize the overall purpose of the change, not just the last commit.
- Keep under 72 characters.

**Description template:**

```markdown
## Summary

- <bullet 1>
- <bullet 2>

## Changes

- <file or component>: <what changed and why>

## Testing

- <how this was tested or verified>

## Related

Closes #<issue number>   ← include only if an issue exists
```

Adapt the template to the actual content. Omit sections that are genuinely not applicable. Do not invent details that are not evident from the diff or conversation.

## HARD STOP — Present Draft and Wait for Approval

**This step is mandatory and cannot be skipped, even mid-conversation or after extended context.**

Present the full PR draft to the user in this format:

```
## Proposed Pull Request

**Target repo:** <base-owner>/<base-repo>
**Push remote:** <head-remote> -> <head-owner>/<head-repo>
**Base branch:** <default branch, e.g. main or master>
**Head branch:** <branch>
**Commits included:** <N commits — list titles>

---

**Title:** <draft title>

**Description:**
<draft description>

---

Ready to push and open the PR. Awaiting your approval.
```

If a new feature branch must be created first, include:

`**Branch action:** create and switch to <branch> before pushing`

Then **STOP completely.** Do not push the branch. Do not call any GitHub API. End your response and wait.

Only continue if the user explicitly approves (e.g. "yes", "go ahead", "looks good", "ship it"). If the user requests changes to the title or description, revise and stop again — do not proceed.

**There is no implicit approval.** Prior conversation context, previous approvals, or urgency are not substitutes for explicit confirmation in the current turn.

## Step 4: Push the Branch

After explicit approval, create the branch first if needed, then push it to `head-remote`:

```bash
git push -u <head-remote> <branch>
```

- If the push is rejected because the remote branch has diverged, stop and report the conflict. Do not force-push without explicit user instruction.
- If the branch already exists on the remote and is up to date, skip the push step and proceed directly to PR creation.

## Step 5: Create the Pull Request

Use the approved title and description to open the PR.

**With gh CLI:**

```bash
gh pr create \
  --repo <base-owner>/<base-repo> \
  --base <default-branch> \
  --head <head-owner>:<branch> \
  --title "<approved title>" \
  --body "$(cat <<'EOF'
<approved description>
EOF
)"
```

When `head-owner` and `base-owner` are the same, `--head <branch>` is also valid. Prefer the explicit `<head-owner>:<branch>` form when the repositories differ.

**With GitHub integration tool (MCP):** Pass the base repository (`base-owner`/`base-repo`), base branch, and head branch explicitly. If the integration cannot represent a cross-repo head branch cleanly, fall back to `gh pr create` instead of guessing.

After the PR is created, print the PR URL so the user can open it directly.

## Step 6: Stop

- Do not merge, approve, or request reviewers unless the user explicitly asks.
- Summarize what was created and include the PR URL.

## Common Mistakes

| Mistake | Correct behavior |
|---|---|
| Pushing before user approves | Always stop after presenting the draft |
| Assuming owner equals authenticated user | Parse owner from remote URL; it may be an org |
| Treating `origin` as both push remote and PR target in a fork | Track `head-remote` and `base-remote` separately |
| Starting on `main` or `master` and pushing it directly | Propose a feature branch first, then create it only after approval |
| Force-pushing on conflict | Stop and report; never force-push without explicit instruction |
| Opening a PR against the wrong base | Confirm default branch before drafting |
| Including only the last commit in the summary | List all commits that will appear in the PR |
| Using personal-account API calls for org repos | Pass the correct `owner` (org name) to all API calls |

## Guardrails

- Never push or open a PR without explicit user approval in the current turn.
- Never merge, close, or modify an existing PR unless explicitly asked.
- Never add AI-attribution lines, `Co-authored-by` trailers for AI tools, or "generated by" footers to the PR title or description.
- Never push to `main`, `master`, or the detected default branch directly. Create or use a feature branch instead.
- If the repo enforces branch protection or required reviewers, report that to the user after the PR is created; do not attempt to bypass or work around those settings.
