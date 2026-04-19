# Comment Triage Guide

Use this file when it is not obvious whether a review comment should lead to a code change, a reply, both, or neither.

When this skill is used in drafting mode, print the proposed replies and fix plans, then stop. Treat later user approval or revision requests as a separate turn.

## Actionable vs Non-Actionable

Actionable comments usually:

- Request a code, docs, or test change.
- Point out a bug, regression risk, or missing edge case.
- Ask a concrete question that blocks review progress.

Usually non-actionable:

- Pure acknowledgements.
- Already-resolved duplicates.
- Comments about code that no longer exists in the current diff, unless the concern still applies.

## Reasonable vs Not Reasonable

Reasonable comments are:

- Technically correct or at least directionally sound.
- Compatible with the repo's goals and existing patterns.
- Small enough in scope to address within the PR, or clearly worth a follow-up.

Not reasonable comments are:

- Factually incorrect.
- Outdated because the code changed after the comment.
- In conflict with an explicit repo requirement or user direction.
- Too broad for the current PR without a separate design discussion.

## Reply Patterns

Reasonable reply pattern:

- Acknowledge the issue.
- State the planned or completed fix.
- Mention verification if relevant.
- When posting, prefer a direct threaded reply to the original review comment.

Not reasonable reply pattern:

- Acknowledge the concern respectfully.
- Explain the reason for not adopting it.
- Offer an alternative, follow-up, or evidence when possible.
- When direct replies are unavailable for the target comment type, quote enough context in the fallback comment to make the mapping obvious.
