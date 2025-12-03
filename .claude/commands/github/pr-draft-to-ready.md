---
name: pr-draft-to-ready
description: Convert draft PR to ready for review after verification
allowed-tools: Bash(gh pr view:*), Bash(gh pr ready:*)
argument-hint: <pr-number>
---

## Pre-loaded Context

`!gh pr view $ARGUMENTS`

---

If $ARGUMENTS is empty, prompt user for PR number.

Mark draft PR #$ARGUMENTS ready for review.

## Pre-flight Checks:

1. **Verify all checks pass:** Review CI/CD status
2. **Confirm all linked issues are addressed:** Check issue closure references
3. **Review test coverage:** Ensure tests are passing and adequate

## If Checks Pass:

1. **Mark ready:** `gh pr ready $ARGUMENTS`
2. **Comment with summary:** Post completion summary to PR

## If Checks Fail:

1. **Report issues found:** List what needs to be fixed
2. **Keep as draft:** Leave PR in draft state until issues resolved
