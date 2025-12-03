---
name: issue-review
description: Review implementation completeness before creating PR - validate against plan and check quality
allowed-tools: Bash(gh issue view:*), Bash(gh label list), Bash(git log:*), Bash(git status), Bash(git diff:*), Grep(*)
argument-hint: <issue-number>
---

Review completed work for issue #$ARGUMENTS before creating PR - validate completeness, quality, and readiness.

## Preloaded Context

`!gh issue view $ARGUMENTS && echo -e "\n========== COMMENTS ==========\n" && gh issue view $ARGUMENTS --comments`

`!gh label list`

`!git log main..HEAD --oneline`

`!git status`

`@docs/plans/issue-$ARGUMENTS-plan.md`

## Purpose

This command performs a pre-PR completeness check after implementation work is done:

- Compares what was built vs what was planned
- Verifies completeness (tests, docs, edge cases)
- Performs quality checks (TODOs, obvious issues)
- Provides go/no-go recommendation for creating PR

Use this **after work is complete, before running `/github:pr-draft`**

## Workflow

### Step 1: Validate Arguments

If $ARGUMENTS is empty, prompt user for issue number.

### Step 2: Load and Analyze Plan (if exists)

From preloaded plan file:

**If plan exists:**
- Extract acceptance criteria or success criteria
- Note key features/changes that were planned
- Identify any specific requirements (tests, docs, etc.)

**If no plan exists:**
- Use issue description for planned scope
- Derive expected changes from issue type (build/fix/docs)

### Step 3: Analyze What Was Actually Done

From preloaded `git log main..HEAD`:

- Count commits on branch
- Summarize scope of changes from commit messages
- Identify files/areas that were modified
- Note any breaking changes or migrations

If helpful, run:
```bash
git diff main..HEAD --stat
```

To see changed files and line counts.

### Step 4: Compare Planned vs Actual

Cross-reference plan/issue requirements with actual changes:

**Completeness check:**
- ✅ Were all planned features/fixes implemented?
- ⚠️ Are any requirements from plan/issue missing?
- 📝 Was extra work done beyond the plan?

**Flag gaps:**
- Missing features mentioned in plan/issue
- Incomplete implementations
- Unaddressed edge cases from discussion

### Step 5: Verify Quality & Completeness

**Tests:**
- Check if new test files were added (search for `test/` or `_test` in changed files)
- For fixes: Was a regression test added?
- For features: Are happy path + edge cases tested?

**Documentation:**
- Check if relevant CLAUDE.md files were updated
- For new models/views: Are they documented in docs/scratchpads?
- Are inline comments present for complex logic?

**Code quality:**
- Search for remaining TODO/FIXME in changed files:
```bash
git diff main..HEAD | grep -i "TODO\|FIXME"
```
- Check for debug artifacts (console.log, binding.pry, debugger)
- Note any obvious code smells from diff

**Edge cases:**
- Review if error handling is present
- Check for nil/empty state handling
- Validate input handling for new features

### Step 6: Check Git State

From preloaded `git status`:

**Uncommitted changes:**
- Warn if uncommitted changes exist
- "You have uncommitted work. Commit before creating PR?"

**Clean state:**
- Confirm branch is ready for PR

### Step 7: Generate Review Report

Output comprehensive report to chat:

**Format:**

```
## Issue #$ARGUMENTS Review Report

### ✅ Completed
- [List what was successfully implemented based on commits/plan]
- [Note any extra work beyond plan]

### ⚠️ Potential Gaps
- [List any planned items that appear missing]
- [Note any incomplete implementations]
- [If none: "No gaps identified"]

### 📋 Quality Checklist

**Tests:** [✓/⚠️] Status of test coverage
**Documentation:** [✓/⚠️] Status of docs/comments
**Code Quality:** [✓/⚠️] TODOs, debug artifacts
**Edge Cases:** [✓/⚠️] Error handling, nil checks

### 📊 Changes Summary
- X commits
- Y files changed
- Key areas modified: [list]

### 🚦 Recommendation

[Ready to create PR / Address items before PR]

**Next steps:**
- [If ready] Run `/github:pr-draft $ARGUMENTS` to create draft PR
- [If gaps] Address the items above, then re-run this review
```

## Output

Direct to chat (review report)

No sandbox file needed - this is analysis/validation.

## Notes

- This is a pre-PR quality gate, not a code review
- Focuses on completeness vs plan, not implementation details
- Can be run multiple times as work progresses
- Helps catch missing requirements before PR
- User can override and proceed to PR even with warnings

## Special Cases

**No plan file:**
- Use issue description as baseline
- Focus on issue type (build/fix/docs) expectations

**Experimental work:**
- Note if this deviates from plan
- Recommend documenting rationale in PR body

**Multiple issues:**
- If PR addresses multiple issues, check each
- Note any cross-issue dependencies