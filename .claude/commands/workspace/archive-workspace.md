---
name: archive-workspace
description: Create or update workspace archive snapshot
allowed-tools: bash()
---

## Pre-loaded Context

!`git branch --show-current`

## Workflow

### Step 1: Validate Workspace Exists

Check if dev/workspace/ directory exists.

If not found:
STOP
Output: "❌ No workspace found at dev/workspace/"
Exit

### Step 2: Determine Archive Name

Get current branch name and generate archive folder name.

Format: `YYMMDD_[type]_description`

Example:

- Branch: `workflow/workspace-enhancements`
- Archive: `251126_[workflow]_workspace-enhancements`

Parse branch name:

- Extract type (before slash)
- Extract description (after slash)
- Add current date as YYMMDD

If branch doesn't follow type/description pattern:
STOP
Output: "❌ Branch must follow format: type/description"
Exit

### Step 3: Create or Update Archive

Create archive directory (if doesn't exist):
`mkdir -p dev/branches/{archive-name}`

Sync workspace to archive:
`rsync -av --delete dev/workspace/ dev/branches/{archive-name}/`

This overwrites existing archive with current workspace state.

### Step 4: Confirm Success

Output:

```
  ✓ Archived: dev/branches/{archive-name}/
  ✓ Workspace remains active on branch
  ℹ Commit when ready: git add dev/branches/ && git commit -m "Archive workspace"
```

## Safety

- ✓ Preserves original workspace (rsync copies, doesn't move)
- ✓ Overwrites existing archive (ensures freshness)
- ✓ Idempotent (safe to run multiple times)
