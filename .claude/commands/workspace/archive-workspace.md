---
name: archive-workspace
description: Creates or updates a workspace directory snapshot.
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

Find existing archive for this branch (matching pattern `*_\[type\]_description`):
`ls -d dev/branches/*_\{type\s}_{description} 2>/dev/null`

If found:
- Rename to current date: `mv "{existing}" "dev/branches/{archive-name}"`

If not found:
- Create: `mkdir -p dev/branches/{archive-name}`

Sync workspace:
`rsync -av --delete dev/workspace/ dev/branches/{archive-name}/`

This overwrites the existing archive with the current workspace state.

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
