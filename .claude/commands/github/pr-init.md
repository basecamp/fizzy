---
name: pr-init
description: Assist with PR body initialization after user creates draft PR
allowed-tools: Bash(gh pr view:*), Bash(git log:*), Bash(gh pr edit:*)
argument-hint: <pr-number>
---

## Pre-loaded Context

`!gh pr view $ARGUMENTS`

`!git log main..HEAD --oneline`

---

If $ARGUMENTS is empty, prompt user for PR number.

Assist with initializing the PR body for PR #$ARGUMENTS after user has created a draft PR.

## Steps:

1. **Review PR context:**
   - PR title and current body
   - Linked issues
   - Files changed
   - Commit history
3. **Analyze structure and suggest improvements**
4. **Draft PR body to sandbox:** Write to `docs/sandbox/pr-{num}-init.md` with:
   - **No 🤖 header** (PR body represents user's work)
   - Written in **first person** (user's voice)
   - Summary of changes
   - Link to related issues (Fixes #X, Closes #Y)
   - Implementation approach
   - Test plan
   - Review notes
5. **Wait for user approval**
6. **Provide command to update PR:**

```bash
gh pr edit $ARGUMENTS -F docs/sandbox/pr-{num}-init.md
```

**Note:** PR bodies represent the user's work and should be written in first person without Claude attribution.
