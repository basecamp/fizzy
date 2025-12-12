---
name: sync-workspace
description: Pulls in changes to the workspace from upstream.
allowed-tools: bash()
---

## Pre-loaded Context

!`git branch`

## Workflow

### Step 1: Check Git State

**Uncommitted changes:** Stop. "Commit or stash before creating new branch."

**Command branch:** If `command` branch is available. Ensure it is checked out. If not, confirm switch to `command`

**Main branch:** If no `command` branch, Ensure `main` is checked out. If not, confirm switch to `main`

### Step 2: Run Script

IF on either a clean `command` or `main` branch:
run `.claude/scripts/sync-workspace.sh`

IF the bash script fails to run: Stop, recommend the user `CHMOD +x` the script in their terminal and then restart this command.

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
