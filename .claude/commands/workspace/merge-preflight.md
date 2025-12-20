---
name: merge-preflight
description: Validate branch readiness for merge with comprehensive report
allowed-tools: bash(), Task(), Read(), Write()
---

## Pre-loaded Context

!`git branch`
!`git status --short`
!`ls -la dev/branches/ 2>/dev/null || echo "No archives yet"`

## Workflow

### Step 0: Load previous report (if exists)

$ARGUMENTS

### Step 1: Validate Basic Git State

Check the current branch is not main or command.

If on main/command:
STOP
Output: "❌ Cannot run preflight from main/command branch"
Exit

Check the working tree is clean.

If uncommitted changes:
Note for report: ⚠️ Uncommitted changes exist 
(ignore merge-preflight.md review)

### Step 2: Archive Workspace (Conditional)

Read WORKSPACE.md (from dev/workspace/ or most recent archive).

Parse "Archive workspace upon merge" checkbox:
`grep "- \[x\] Archive workspace" WORKSPACE.md`

If checked:

Launch Task(general-purpose) agent with instructions:

"Execute the /workspace/archive-workspace command.

This creates or updates workspace archive in dev/branches/.
Report the archive location and success, or any errors encountered."

Wait for agent completion.

If agent reports **success:**

    Stage archive:
      git add dev/branches/{archive-name}/

    Commit archive (ignore if nothing to commit):
      git commit -m "Archive workspace before merge" || true

    Verify archive exists:
      ls dev/branches/{archive-name}/README.md >/dev/null 2>&1

    If verified:
      Note for report: ✓ Workspace archived (current snapshot committed)

    If missing:
      Note for report: ❌ Archive verification failed
      BLOCKING ISSUE

If agent reports **failure:**

    Note for report: ❌ Archive creation failed - {error}
    BLOCKING ISSUE

If **unchecked:**

    Note for report: ℹ Archive skipped (not configured in WORKSPACE.md)

### Step 3: Validate Task Completion

Use Task(Explore) agent to find all task files:

    "Search dev/workspace/tasks/ (or archive if workspace moved) for all .md files.
    
    For each file found:
    
    - Read the file
    - Parse for incomplete task checkboxes: - [ ]
    - List any incomplete tasks with filename reference
    
    Return summary of incomplete tasks grouped by file.

Wait for agent response.

If incomplete tasks found:
Note for report: ❌ Incomplete tasks in {files}
BLOCKING ISSUE

If all tasks complete:
Note for report: ✓ All tasks completed

### Step 4: Validate WORKSPACE.md Configuration

Read WORKSPACE.md.

Parse merge strategy:
Check exactly one of: Squash merge / Rebase merge / Merge commit

If no strategy selected or multiple selected:
Note for report: ❌ Invalid merge strategy configuration
BLOCKING ISSUE

If valid strategy:
Note for report: ✓ Merge strategy: {strategy}

Parse post-merge actions:

- Delete branch after merge
- Archive workspace upon merge

Note configuration for report.

### Step 5: Validate Git State

Check working tree clean:
`git status --short`

If uncommitted changes:
Note for report: ❌ Uncommitted changes exist
BLOCKING ISSUE

Check all commits pushed:
`git status | grep "ahead of"`

If ahead of origin:
Note for report: ⚠️ Unpushed commits exist
ATTENTION REQUIRED

Check for merge conflicts with command or main (if using):
`git fetch origin command` (main)
`git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main`

If conflicts detected:
Note for report: ❌ Merge conflicts with main
BLOCKING ISSUE

### Step 6: Check PR Status

Check if PR exists:
gh pr view --json number,state,title,isDraft 2>/dev/null

If no PR:
SKIP

If PR exists:

Check not draft:
If draft:
Note for report: ⚠️ PR is in draft state
ATTENTION REQUIRED

Check CI status:
gh pr checks

    If failing:
      Note for report: ❌ CI checks failing
      BLOCKING ISSUE

If no PR:
Note for report: ℹ No PR exists (will be created during merge)

### Step 7: Generate Report

Compile all validation results into report.

Structure:

# Merge Preflight Report

Branch: {branch-name}
Target: main
Generated: {timestamp}

## ✅ PASSED ({count})

[List all passing validations]

## ⚠️ ATTENTION REQUIRED ({count})

[List warnings with suggested actions]

## ❌ BLOCKING ISSUES ({count})

[List failures that prevent merge]

  ---

## Merge Configuration

[From WORKSPACE.md]

## Next Steps

[Instructions based on status]

Save report to:
dev/workspace/reviews/merge-preflight.md

Create reviews/ directory if doesn't exist.

### Step 8: Output Result

If blocking issues exist:
Output: "❌ {count} blocking issues found"
Output: "Report saved: dev/workspace/reviews/merge-preflight.md"
Output: "Fix issues and rerun: /workspace/merge-preflight"

If only warnings:
Output: "⚠️ {count} items need attention"
Output: "Report saved: dev/workspace/reviews/merge-preflight.md"
Output: "Review and address, then rerun or proceed: /workspace/merge-branch"

If all passed:
Output: "✅ All preflight checks passed!"
Output: "Report saved: dev/workspace/reviews/merge-preflight.md"
Output: "Ready to merge: /workspace/merge-branch"

## Safety

- ✓ Non-destructive (only validation and reporting)
- ✓ Rerunnable (can check multiple times)
- ✓ Commits archive automatically if configured
- ✓ Comprehensive validation before merge
