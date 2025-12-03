---
name: issue-branch
description: Create a properly named branch for an issue with git housekeeping
allowed-tools: Bash(gh issue view:*), Bash(git status), Bash(git branch:*), Bash(git checkout:*), Bash(git fetch:*)
argument-hint: <issue-number>
---

Create a properly named branch for issue #$ARGUMENTS and handle git housekeeping.

## Pre-loaded Context

`!gh issue view $ARGUMENTS`

`!git status`

`!git branch --show-current`

## Purpose

This command creates a clean, properly named branch for starting work on an issue. It handles:

- Branch naming based on issue type
- Fetching latest from origin/main
- Checking for uncommitted changes
- Handling existing branches
- Clean starting point from main

## Workflow

### Step 1: Validate Arguments

If $ARGUMENTS is empty, prompt user for issue number.

### Step 2: Analyze Issue Labels

From the pre-loaded issue view, identify the type label:

- `build` or `kickoff` → branch prefix: `feature/`
- `fix` → branch prefix: `fix/`
- `workflow` → branch prefix: `workflow/`
- `docs` → branch prefix: `docs/`
- `chore` → branch prefix: `chore/`
- `refactor` → branch prefix: `refactor/`
- No type label → default to `feature/`

### Step 3: Create Branch Name

Format: `{prefix}{issue-number}-{sanitized-title}`

**Example:**

- Issue #36: "[Workflow] - Upgrade slash commands to control github workflow"
- Branch: `workflow/36-upgrade-slash-commands`

**Sanitization rules:**

- Convert to lowercase
- Replace spaces with hyphens
- Remove special characters except hyphens
- Trim to reasonable length (~50 chars after prefix)

### Step 4: Check Git State

From pre-loaded git status:

**If uncommitted changes exist:**

- Stop and inform user: "You have uncommitted changes. Please commit or stash them before creating a new branch."
- Show files with changes
- Provide options:
    - Commit changes on current branch
    - Stash changes: `git stash save "WIP: {current-branch}"`
    - Continue anyway (only if user explicitly requests)

**If on non-main branch:**

- Inform user current branch
- Confirm before switching: "Currently on {current-branch}. Switch to new branch {new-branch-name}?"

### Step 5: Fetch Latest Main

```bash
git fetch origin main
```

Check if fetch succeeds. If it fails, inform user and ask if they want to proceed without fetching.

### Step 6: Check if Branch Exists

```bash
git branch --list {branch-name}
```

**If branch exists locally:**

- Inform user: "Branch {branch-name} already exists locally."
- Offer to checkout existing branch: `git checkout {branch-name}`
- This is most common case (resuming work)

**If branch doesn't exist:**

- Proceed to create new branch

### Step 7: Create and Checkout Branch

```bash
git checkout -b {branch-name} origin/main
```

This creates new branch based on latest origin/main.

### Step 8: Confirm Success

Show confirmation message:

```
✓ Created and checked out branch: {branch-name}
✓ Based on latest origin/main
✓ Ready to start work on issue #{number}

Next steps:
- Run `/github:issue-start {number}` to analyze issue readiness
- Or start implementation directly
```

## Safety Checks

- ⚠️ Warn if uncommitted changes (requires manual resolution)
- ⚠️ Confirm if switching from non-main branch
- ⚠️ Handle existing branch by offering to check it out
- ⚠️ Verify origin/main is accessible
- ✓ Always create from origin/main for clean start

## Output

Direct to chat (branch creation confirmation and next steps)

## Examples

**Example 1: Clean state**

```
Issue #42 [build] - Add client filtering
Current branch: main
Status: clean

Creating branch: feature/42-add-client-filtering
✓ Fetched origin/main
✓ Created branch from origin/main
✓ Ready to start work
```

**Example 2: Uncommitted changes**

```
Issue #42 [build] - Add client filtering
Current branch: feature/36-slash-commands
Status: 3 files modified

⚠️ You have uncommitted changes:
  M .claude/commands/github/issue-start.md
  M .claude/commands/github/issue-close.md
  M docs/sandbox/issue-36-plan.md

Please commit or stash changes before creating new branch:
  git add . && git commit -m "message"
  git stash save "WIP: feature/36"
```

**Example 3: Branch exists**

```
Issue #42 [build] - Add client filtering
Current branch: main

Branch feature/42-add-client-filtering already exists.
✓ Checked out existing branch
✓ Ready to resume work on issue #42
```

## Notes

- This command is typically run before `/github:issue-start` to set up workspace
- Creates clean starting point from origin/main, not from current branch
- Encourages explicit commit/stash decisions for safety
- Handles common resume-work case (branch exists)
