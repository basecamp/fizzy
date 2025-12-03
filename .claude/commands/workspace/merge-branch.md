---
name: merge-branch
description: Execute PR merge after preflight validation
allowed-tools: bash(), Task(), Read()
---

## Pre-loaded Context

!`git branch --show-current`
!`cat dev/workspace/reviews/merge-preflight.md 2>/dev/null || echo "No preflight report found"`

## Workflow

### Step 1: Verify Preflight Report

Check that dev/workspace/reviews/merge-preflight.md exists.

If missing:
STOP
Output: "❌ No preflight report found"
Output: "Run: /workspace/merge-preflight"
Exit

Read preflight report.

Check for "All preflight checks passed" status.

If the report shows blocking issues:
STOP
Output: "❌ Preflight report shows blocking issues"
Output: "Fix issues and rerun: /workspace/merge-preflight"
Exit

### Step 2: Read Merge Configuration

Read WORKSPACE.md from dev/workspace/ or archive.

Parse merge strategy:

- [x] Squash merge → --squash
- [x] Rebase merge → --rebase
- [x] Merge commit → --merge

Parse post-merge actions:

- Delete branch after merge (yes/no)

If the merge strategy is invalid:
STOP
Output: "❌ Invalid WORKSPACE.md configuration"
Exit

### Step 3: Check/Create PR

Check if PR exists:
`gh pr view --json number -q .number 2>/dev/null`

If PR exists:
Note PR number
Output: "✓ Using existing PR #{number}"

If no PR exists:

Use Task(Explore) agent to gather PR content:

"Gather content for PR creation from:

1. Purpose: Read dev/branches/{archive}/CLAUDE.md 'Purpose' section
2. Completed tasks: Parse dev/branches/{archive}/tasks/*.md for checked items
3. Commit summary: `git log main..HEAD --oneline`

Synthesize PR body:

## Summary

[Purpose]

## What Changed

[Completed tasks + commit highlights]

Return PR title and body."

Wait for agent response.

Create PR:
`gh pr create --title "{title}" --body "{body}"`

Get PR number:
`gh pr view --json number -q .number`

Output: "✓ Created PR #{number}"

### Step 4: Push Final Changes

Ensure all commits pushed:
git push origin {branch-name}

Output: "✓ Branch pushed to remote"

### Step 5: Execute Merge (Without Branch Deletion)

Merge PR with configured strategy (WITHOUT --delete-branch flag):
`gh pr merge {pr-number} {merge-strategy-flag}`

Never auto-delete branch at this stage - user confirms after verification.

If merge fails:
STOP
Output: "❌ Merge failed: {error}"
Output: "Check PR and resolve issues manually"
Exit

Output: "✓ PR merged successfully"

### Step 6: Update Main Branch

Switch to main and update:
git checkout main
git pull origin main

Output: "✓ Switched to main and updated"

Verify merge landed on main:
git log --oneline -1

Output: "✓ Latest commit: {commit-message}"

### Step 7: User Confirmation for Branch Deletion

Read WORKSPACE.md "Delete branch after merge" configuration.

If delete branch configured:

Use AskUserQuestion tool:

Question: "Merge complete! Main branch updated successfully. Delete the feature branch now?"

Context: "Branch: {feature-branch-name}"
Context: "This will delete both local and remote branches."
Context: "Archive preserved at: dev/branches/{archive-name}/" [if archived]

Options:

- "Yes, delete branch" → Proceed to Step 8
- "No, keep branch" → Skip to Step 9

If delete branch NOT configured:
Skip to Step 9 (user wants to keep branch)

### Step 8: Delete Branch (If Confirmed)

If user confirmed deletion:

Delete remote branch:
`git push origin --delete {branch-name}`

Output: "✓ Remote branch deleted"

Delete local branch:
`git branch -D {feature-branch}`

Output: "✓ Local branch deleted"

### Step 9: Final Summary

Output:

✅ Merge complete!

PR: {pr-url}
Strategy: {squash|rebase|merge}
Branch: {deleted|retained}
Archive: dev/branches/{archive-name}/ [if archived]

You are now on: main

## Safety

- ✓ Requires clean preflight report (no validation bypass)
- ✓ Verifies merge strategy configuration before executing
- ✓ Archive already committed by preflight (no context loss risk)
- ✓ Clear success/failure messaging
