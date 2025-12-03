---
name: pr-draft
description: Create a draft pull request early in workflow as a placeholder for progressive updates
allowed-tools: Bash(gh issue view:*), Bash(git branch:*), Bash(git status), Bash(git diff:*), Bash(git push:*), Bash(gh pr create:*)
argument-hint: <issue-number>
---

Create a draft pull request for issue #$ARGUMENTS as an early placeholder for progressive development.

## Preloaded Context

`!gh issue view $ARGUMENTS`

`!git branch --show-current`

`!git status`

`!git log main..HEAD --oneline`

## Purpose

This command creates a draft PR early in the workflow as a placeholder:

- Verifies git state and branch
- Pushes branch to remote if needed
- Creates draft PR with minimal body (just links issue)
- Allows progressive updates and commenting during work
- Use `/github:pr-init` later to fill out comprehensive body before review

## Workflow

### Step 1: Validate Arguments

If $ARGUMENTS is empty, prompt user for issue number.

### Step 2: Verify Current Branch

From pre-loaded `git branch --show-current`:

- Confirm user is NOT on `main` or `development`
- If on main/development, warn and stop: "Cannot create PR from protected branch. Switch to feature branch first."
- Show current branch name

### Step 3: Check Git State

From pre-loaded `git status`:

**If uncommitted changes exist:**

- Warn user: "You have uncommitted changes. Commit them before creating PR?"
- Show files with changes
- Wait for user confirmation to proceed or stop

**If working tree is clean:**

- Proceed to next step

### Step 4: Review Changes

From pre-loaded `git log main..HEAD --oneline`:

- Show commits that will be included in PR
- Summarize scope of changes
- If no commits exist (branch matches main), stop: "No commits to create PR from. Make changes first."

### Step 5: Push Branch to Remote

Check if branch is tracking remote:

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u}
```

**If not tracking or behind:**

```bash
git push -u origin HEAD
```

**If already pushed and up to date:**

- Skip push, proceed to PR creation

### Step 6: Create Draft PR with Minimal Body

Create draft PR with minimal placeholder body:

**Title format:**

- Use issue title without type prefix
- Example: Issue "[Build] - Add dark mode" → PR "Add dark mode"

**Body:**

- Simple: `Closes #$ARGUMENTS`
- That's it - comprehensive body comes later with `/github:pr-init`

```bash
gh pr create --draft --base main --title "Title from issue" --body "Closes #$ARGUMENTS"
```

### Step 7: Verify PR Created

After creation:

- Capture PR number from output
- Show PR URL
- Confirm PR is linked to issue

### Step 8: Provide Next Steps

Display to user:

```
✓ Created draft PR #{number} for issue #$ARGUMENTS
✓ URL: [PR URL]
✓ Linked to issue with "Closes #$ARGUMENTS"

Next steps:
- Continue implementation work (commits will show in PR)
- Team can comment on draft PR during development
- Run `/github:pr-init {pr-number}` to fill out comprehensive body before review
- Run `/github:pr-draft-to-ready {pr-number}` when ready for review
```

## Output

Direct to chat with PR creation summary and next steps.

## Notes

- Always creates draft PRs (not ready for review)
- Creates minimal PR body - just issue link
- Draft PR serves as placeholder during development
- Comprehensive body added later with `/github:pr-init` before review
- This is the "create early, update later" workflow for draft PRs

## Special Cases

**Experimental/Parallel PRs:**

- Command detects if multiple PRs exist for same issue
- Suggests adding `experimental` label if available
- Recommends adding approach comparison in PR body

**No issue number:**

- Can be used without issue number if user just wants to create PR
- Skip issue linking in that case
