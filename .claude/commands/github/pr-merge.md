---
name: pr-merge
description: Assist with PR merge by analyzing context and drafting merge commit message
allowed-tools: Bash(gh pr view:*), Bash(git log:*), Bash(gh pr merge:*)
argument-hint: <pr-number>
---

## Pre-loaded Context

`!gh pr view $ARGUMENTS`

`!git log main..HEAD --oneline`

---

If $ARGUMENTS is empty, prompt user for PR number.

Assist with merging PR #$ARGUMENTS by analyzing context and drafting a comprehensive merge commit message.

## Steps:

1. **Analyze PR context:**
    - PR details (title, body, linked issues)
    - Commit history on branch: `git log main..HEAD`
    - Files changed
    - Acceptance criteria completion status
2. **Check PR readiness:**
    - Verify PR is not in draft state
    - Check linked issues are addressed
    - Verify CI/checks passing
3. **Draft merge commit message to sandbox:** Write to `docs/sandbox/pr-$ARGUMENTS-merge.md` with:
    - **No 🤖 header** (merge commit represents user's work)
    - Written in **past tense** describing what was accomplished
    - **What was built** (from PR title/body)
    - **Why it was built** (from linked issues)
    - **Key implementation details**
    - **Breaking changes or notes** (if any)
    - Summary of what will auto-close
    - Co-author information if multiple contributors
4. **Provide verification notes or warnings**
5. **Wait for user approval**
6. **Provide merge command:**

```bash
# For squash merge:
gh pr merge $ARGUMENTS --squash -F docs/sandbox/pr-$ARGUMENTS-merge.md

# For regular merge:
gh pr merge $ARGUMENTS --merge -F docs/sandbox/pr-$ARGUMENTS-merge.md
```

**Writing style:**

- Past tense ("Added feature X", "Fixed bug Y")
- Focus on what was accomplished and why
- Include context for future reference
- Follow conventional commits format if applicable

**Note:** Merge commits represent the user's work and should summarize the entire PR comprehensively.
