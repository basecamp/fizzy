---
name: sync-workspace
description: Pulls in changes to the workspace from upstream.
allowed-tools: bash()
---

## Pre-loaded Context

!`git remote -v`  
!`git branch`

## Workflow

### Step 1: Check Git State

**No workspace remote:** Stop, recommend the user add the workspace remote:  
`git remote add workspace https://github.com/dilberryhoundog/dev-workspace.git`

**Uncommitted changes:** Stop. "Commit or stash before creating new branch."

**Command branch:** If `command` branch is available. Ensure it is checked out. If not, confirm switch to `command`

**Main branch:** If no `command` branch, Ensure `main` is checked out. If not, confirm switch to `main`.

### Step 2: Run Command

IF on either a clean `command` or `main` branch run:
```bash
git pull workspace main -m "🔄 chore: sync workspace from upstream"`
```

### Step 3: Merge Conflicts

IF merge conflicts exist, work through them interactively with the user.

### Step 4: Confirm Success

Output:

```
  ✓ Workspace successfully synced to {branch}
```

## Safety

- ✓ Ensure only the parent branch is updated
- ✓ Works through merge conflicts
- ✓ Idempotent (safe to run multiple times)
