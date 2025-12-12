---
name: new-workspace
description: Create new branch with workspace folder and CLAUDE.md
allowed-tools: Bash(git status), Bash(git branch:*), Bash(git checkout:*), Bash(git fetch:*), Bash(git add:*), Bash(git commit:*), Write, Read, Edit
argument-hint: <branch purpose>
---

Create a new branch with a workspace environment for isolated work.

## Description

$ARGUMENTS

## Pre-loaded Context

!`git status`

!`git branch`

## Workflow

### Step 1: Validate Arguments

If no description, prompt: "What are you working on?"

### Step 2: Determine Branch Type

Analyze description and select prefix:

- `feature/` - New features, enhancements (default)
- `fix/` - Bug fixes, patches
- `docs/` - Documentation changes
- `chore/` - Maintenance, tooling, dependencies
- `refactor/` - Code restructuring
- `workflow/` - CI/CD, process improvements

### Step 3: Create Branch Name

Format: `{type}/{sanitized-description}`

Sanitization:

- Lowercase
- Spaces → hyphens
- Remove special chars except hyphens
- Max ~40 chars

### Step 4: Check Git State

**Uncommitted changes:** Stop. "Commit or stash before creating new branch."

**Command branch:** If `command` branch is available. Ensure it is checked out. If not, confirm switch to `command`

**Main branch:** If no `command` branch, Ensure `main` is checked out. If not, confirm switch to `main`

### Step 5: Fetch & Create Branch

**IF** on `main` branch:
```bash
git fetch origin main
git checkout -b {branch-name} origin/main
```
**IF** on `command` branch:
```bash
git fetch origin command
git checkout -b {branch-name} origin/command
```

If branch exists, checkout existing.

### Step 6: Update CLAUDE.md

dev/workspace/CLAUDE.md

1. Edit only these placeholders:
    - `{branch-name}` → actual branch name
    - `{YYYY-MM-DD}` → current date
    - `## Purpose` → expanded user description
    - `# Workspace` → `# [Type] Title Case Description`
2. Preserve all checkboxes and configuration

### Step 7: Pause for Configuration

```
✓ Branch: {branch-name}
✓ Workspace: dev/workspace/CLAUDE.md
✓ Command paused for you to make changes. Can I commit the workspace now?
```

Wait for user confirmation, then proceed to Step 8.

### Step 8: Commit Workspace

```bash
git add -A
git commit -m "Initialize workspace"
```

## Safety

- ⚠️ Stop on uncommitted changes
- ⚠️ Confirm on non-main branch switch
- ✓ Always create from origin/main
- ✓ Auto-commit workspace setup
