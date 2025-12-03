# Workspace Merge Commands

Three-command workflow for safely merging feature branches with workspace preservation.

## Commands

### `/workspace/archive-workspace`

**Purpose:** Create or update workspace archive snapshot for cross-branch reference.

**When to use:**

- Create milestone snapshots during long-running branches
- Share progress with other branches
- Before risky refactors (safety checkpoint)

**What it does:**

- Creates/updates archive in `dev/branches/YYMMDD_[type]_description/`
- Preserves workspace structure
- Renames CLAUDE.md → README.md in archive
- Does NOT commit (user controls git workflow)

**Usage:**

```bash
/workspace/archive-workspace

# Commit when ready:
git add dev/branches/
git commit -m "Archive workspace"
```

---

### `/workspace/merge-preflight`

**Purpose:** Validate branch readiness for merge with a comprehensive report.

**When to use:**

- Before merging any feature branch
- After fixing issues (rerun to verify)
- To check merge readiness status

**What it does:**

1. Archives workspace if configured in WORKSPACE.md (via agent)
2. Validates task completion across all task files
3. Checks WORKSPACE.md configuration (merge strategy, post-merge actions)
4. Validates git state (clean tree, pushed commits, no conflicts)
5. Checks PR status (exists, not draft, CI passing)
6. Generates detailed report in `dev/workspace/reviews/merge-preflight.md`

**Validation categories:**

- ✅ PASSED: All good
- ⚠️ ATTENTION REQUIRED: Warnings, may proceed with caution
- ❌ BLOCKING ISSUES: Must fix before merge

**Usage:**

```bash
/workspace/merge-preflight

# If issues found, fix and rerun:
/workspace/merge-preflight

# When all passed:
/workspace/merge-branch
```

---

### `/workspace/merge-branch`

**Purpose:** Execute PR merge after preflight validation with user-controlled branch deletion.

**When to use:**

- After preflight shows "All checks passed"
- Ready to merge and optionally delete branch

**What it does:**

1. Verifies clean preflight report exists
2. Reads merge configuration from WORKSPACE.md
3. Creates PR if doesn't exist (using archive content)
4. Pushes final changes to remote
5. Merges PR with configured strategy (WITHOUT auto-deleting branch)
6. Switches to main and verifies merge
7. **Asks user confirmation before deleting branch** (if configured)
8. Deletes branch only after user confirms

**Usage:**

```bash
/workspace/merge-branch

# After merge completes:
# → If branch deletion configured: "Delete feature branch now?"
# → User chooses: Yes (delete) or No (keep)
# → Result: Branch merged, user controls deletion
```

---

## Workflow Examples

### Standard Flow

```bash
# 1. Complete work
git add .
git commit -m "Complete feature"
git push

# 2. Check readiness
/workspace/merge-preflight
  → Archives workspace if configured
  → Validates everything
  → Generates report

# 3. Fix any issues, rerun
/workspace/merge-preflight
  ✅ All checks passed!

# 4. Merge
/workspace/merge-branch
  ✓ PR merged
  ✓ Switched to main
  ✓ Main updated

  # User prompted (if delete configured):
  ? "Delete feature branch now?"
  → User: "Yes, delete branch"

  ✓ Remote branch deleted
  ✓ Local branch deleted
```

### Long-Running Branch with Early Archive

```bash
# Week 1: Significant progress
/workspace/archive-workspace
git add dev/branches/ && git commit -m "Archive milestone 1"
git push

# Other branches can now reference this work

# Week 2-3: Continue working
# ... more commits ...

# Week 3: Ready to merge
/workspace/merge-preflight
  → Updates archive with latest changes
  ✅ All checks passed!

/workspace/merge-branch
```

### Quick Fix (No Archive)

```bash
# Fix branch with no historical value
# Edit WORKSPACE.md: uncheck "Archive workspace upon merge"

/workspace/merge-preflight
  ℹ Archive skipped (not configured)
  ✅ All checks passed!

/workspace/merge-branch
  ✓ Merged without archive
```

---

## WORKSPACE.md Configuration

Commands read configuration from `dev/workspace/WORKSPACE.md`:

### Merge Strategy (Required)

Select exactly one:

```markdown
- [x] Squash merge
- [ ] Rebase merge
- [ ] Merge commit
```

### Post-Merge Actions

```markdown
- [x] Delete branch after merge
- [x] Archive workspace upon merge
```

**Archive workspace upon merge:**

- Checked: Preflight archives + commits automatically
- Unchecked: No archive created (for quick fixes)

**Delete branch after merge:**

- Checked: Branch deleted locally and remotely after merge
- Unchecked: Branch retained (for ongoing work)

---

## Safety Features

### Archive Protection

- Archive always current before merge (preflight ensures this)
- Archive committed before merge execution
- Workspace preserved on branch until deletion
- `.gitattributes` prevents workspace from merging to main

### Validation Layers

1. Preflight validates comprehensively
2. Merge-branch requires clean preflight report
3. Cannot bypass validation

### User-Controlled Branch Deletion

- Merge completes BEFORE branch deletion
- User verifies main updated successfully
- User explicitly confirms branch deletion
- Can inspect merged code before deleting branch
- No accidental branch deletion

### Failure Prevention

- Archive only if configured (no unnecessary archives)
- Always fresh archive (preflight overwrites stale)
- Clear blocking issues prevent merge
- Comprehensive error messages
- Branch deletion separated from merge (safer)

---

## File Locations

**Commands:** `.claude/commands/workspace/`

- `archive-workspace.md`
- `merge-preflight.md`
- `merge-branch.md`

**Reports:** `dev/workspace/reviews/`

- `merge-preflight.md` (generated by preflight)

**Archives:** `dev/branches/`

- `YYMMDD_[type]_description/` (workspace snapshots)

---

## Architecture Notes

### Why Three Commands?

**Separation of concerns:**

- Archive: Pure file operations
- Preflight: Orchestration + validation + reporting
- Merge-branch: Simple execution

**Benefits:**

- Each command focused and simple
- Preflight can be rerun without side effects
- Merge-branch has no complex logic
- Archive useful outside merge workflow

### Agent Orchestration

Preflight uses Task(general-purpose) agents to:

- Execute archive-workspace command
- Search task files for completion status
- Gather PR content from archive

This delegates complex operations while maintaining control over validation and commits.

### Always Archive in Preflight

When "Archive workspace upon merge" is checked, preflight ALWAYS archives (no freshness checks).

**Why:**

- Guarantees current archive before merge
- No edge cases (stale archive impossible)
- Simple logic (no conditionals)
- Idempotent (safe to rerun)

**Cost:** Slight redundancy if archive recently updated
**Benefit:** Zero possibility of stale archive

---

## Testing These Commands

Before installing to `.claude/commands/workspace/`:

1. Review each command file
2. Test archive-workspace on test branch
3. Test preflight with various WORKSPACE.md configurations
4. Test merge-branch on throwaway PR
5. Verify report format in `reviews/merge-preflight.md`

---

## Installation

When ready:

```bash
# Backup existing commands
mv .claude/commands/workspace/archive-workspace.md .claude/commands/workspace/archive-workspace.md.bak
mv .claude/commands/workspace/merge-branch.md .claude/commands/workspace/merge-branch.md.bak

# Copy new commands
cp dev/workspace/filebox/merge-commands/archive-workspace.md .claude/commands/workspace/
cp dev/workspace/filebox/merge-commands/merge-preflight.md .claude/commands/workspace/
cp dev/workspace/filebox/merge-commands/merge-branch.md .claude/commands/workspace/
```
