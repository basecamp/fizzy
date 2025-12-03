---
name: issue-improver
description: Improve an existing issue by analyzing, collaborating with user, and applying best template
allowed-tools: Bash(gh issue view:*), Bash(gh issue edit:*)
argument-hint: <issue-number>
---

If $ARGUMENTS is empty, prompt user for issue number.

## Pre-loaded Context

`!gh issue view $ARGUMENTS`

`@.github/ISSUE_TEMPLATE/bug-report.yml`

`@.github/ISSUE_TEMPLATE/claude-task.yml`

`@.github/ISSUE_TEMPLATE/feature-request.yml`

`@.github/ISSUE_TEMPLATE/github-workflow.yml`

`@.github/ISSUE_TEMPLATE/quick-capture.yml`

`@.github/ISSUE_TEMPLATE/refactor-chore.yml`

---

Claude needs to help improve issue #$ARGUMENTS by analyzing it, collaborating with the user to fill gaps, and restructuring it using the most appropriate template.

## Step 1: Analyze Current Issue

The current issue content is pre-loaded above via `!gh issue view $ARGUMENTS`.

## Step 2: Identify Gaps and Template Match

Based on the issue content, Claude identifies:

- Missing or weak sections
- Which template fits best: *(prioritise keeping the existing template)*
    - `claude-task` - For tasks Claude Code should execute
    - `feature-request` - For new feature proposals
    - `bug-report` - For bugs and issues
    - `github-workflow` - For GitHub workflow improvements
    - `quick-capture` - For quick notes/ideas
    - `refactor-chore` - For refactoring and maintenance

## Step 3: Collaborate with User

Claude asks targeted questions to fill in or improve template sections.

## Step 4: Draft Improved Version to Sandbox

Claude drafts the improved issue body to `docs/sandbox/issue-$ARGUMENTS-improved.md` formatted according to the matched template, with:

- Clear title suggestion (if needed)
- All template sections filled
- Original content preserved and enhanced
- Proper formatting and structure
- Written in third person, present tense (issue body style, no 🤖 header)

## Step 5: Wait for Approval

After user reviews and approves the sandbox file, Claude provides the command to update the issue:

```bash
gh issue edit $ARGUMENTS -F docs/sandbox/issue-$ARGUMENTS-improved.md
```

And optionally suggests title and label updates if recommended.

---

**Note:** This is a collaborative process. Claude works with the user to ensure the improved issue captures their intent while following project conventions. All content is drafted to sandbox for user review before posting to GitHub.
