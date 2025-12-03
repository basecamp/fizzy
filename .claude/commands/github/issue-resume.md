---
name: issue-resume
description: Resume work on an issue using label-driven routing or user-provided context
allowed-tools: Bash(gh issue view:*), Bash(gh label list), Bash(git log:*), Bash(git status), Bash(git branch:*)
argument-hint: <issue-number>
---

Resume work on issue #$ARGUMENTS using label-driven routing or user-provided context.

**Validation:** If $ARGUMENTS is empty, prompt user for issue number.

## Pre-loaded Context

`!gh issue view $ARGUMENTS && echo -e "\n========== COMMENTS ==========\n" && gh issue view $ARGUMENTS --comments`

`!gh label list`

`!git log --oneline -10`

`!git status`

## Steps:

**Decision Tree (evaluate in order):**

**Criterion 1: Completed/closed issue**

- Check: `state: CLOSED` in metadata
- Response: "This issue is closed. How would you like to resume work? (reopen, create follow-up, review implementation?)"

**Criterion 2: Stage label present (not in-progress)**

- Check labels: `improve-issue`, `blocked`, `needs-discussion`, `plan`
- Response: Guide to stage-specific work

      **`improve-issue` label:**
        - "This issue needs improvement before continuing."
        - "Run `/github:issue-improver {number}` or tell me what to clarify"

      **`blocked` label:**
        - Identify blockers from issue body
        - "This issue is blocked by: [list blockers]"
        - "Which blocker should we resolve first?"

      **`needs-discussion` label:**
        - "This issue needs discussion before implementation."
        - "What aspect would you like to discuss?"

      **`plan` label:**
        - "This issue is in planning phase."
        - "Would you like to: (a) Review/update plan, (b) Start implementation, (c) Create sub-tasks?"

**Criterion 3: In-progress label**

- Check labels: `in-progress`
- Assess progress (see Progress Assessment below)
- Show progress summary
- Ask: "What would you like to work on next?"

**Criterion 4: Unclear context (no stage labels)**

- "This issue doesn't have clear stage labels."
- "How would you like to proceed? (start work, plan first, review requirements?)"

## Progress Assessment (Criterion 3):

Search in this order until reasonable progress view is attained:

1. **Recent commits on current branch:**
    - `git log --oneline --grep="#{number}" -10`
    - `git log --oneline -10` (if no issue reference found)
    - Show commits that relate to issue

2. **Files mentioned in issue:**
    - Extract file paths from issue body
    - Check if files exist: `ls {file}` or `git log -1 --oneline -- {file}`
    - Note: "Created" / "Modified" / "Not found"

3. **Acceptance criteria checkboxes:**
    - Parse issue body for `- [ ]` and `- [x]` patterns
    - Count completed vs remaining
    - Show: "Progress: X/Y tasks completed"

**Progress Summary Format:**

```
📊 Progress on Issue #{number}

Recent commits:
- abc1234 Add feature X
- def5678 Update tests for Y

Files mentioned:
✓ path/to/file.rb (modified)
✓ path/to/test.rb (created)
⚠️ path/to/config.yml (not found)

Acceptance criteria: 5/8 completed

What would you like to work on next?
```

## Output Format:

Direct to chat (no sandbox needed - this is analysis/orientation)

**Example responses:**

```
🔄 Issue #21 [build, in-progress]

📊 Progress Summary:
Recent work:
- Created /github:pr-init command
- Created /github:pr-merge command
- Created /github:issue-start command

Remaining tasks:
- [ ] Update /github:issue-improver
- [ ] Update /github:issue-plan
- [ ] Update /github:issue-close
- [ ] Create /github:issue-resume (this command!)

What would you like to work on next?
```

```
🔄 Issue #25 [build, blocked]

This issue is blocked by:
- Issue #23 (authentication system)
- Missing design documentation

Which blocker should we resolve first, or would you like to switch tasks?
```

```
🔄 Issue #30 [build]

User context: "add validation to the form"

Looking at issue #30 (User Registration Form), I can see the form structure.
Which fields need validation? (email, password, name, all of them?)
```

```
⚠️ Issue #18 is closed

This issue was completed and closed on Oct 14.
How would you like to resume? (reopen, create follow-up, review implementation?)
```

**Writing style:**

- Conversational and collaborative
- Clear visual indicators (🔄 📊 ✓ ⚠️)
- Actionable questions
- Context-appropriate guidance
- Short and focused

## Notes:

- This command assumes the issue was already validated (don't repeat full fidelity analysis)
- Focus on "where are we?" and "what's next?" rather than "is this ready?"
- User context always takes priority over decision tree
- Progress assessment is opportunistic - use what's easily available
- Keep responses short - user knows the issue, just needs orientation
