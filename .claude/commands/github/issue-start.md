---
name: issue-start
description: Analyze issue readiness and provide orientation before starting work
allowed-tools: Bash(gh issue view:*), Bash(gh label list)
argument-hint: <issue-number>
---

Analyze a github issue or comment for readiness and provide orientation before starting work.

## Pre-loaded Context

`!gh issue view $ARGUMENTS && echo -e "\n========== COMMENTS ==========\n" && gh issue view $ARGUMENTS --comments`

`!gh label list`

`@docs/plans/issue-$ARGUMENTS-plan.md`

## Steps:

1. **Validate arguments:**
   - If $ARGUMENTS is empty, prompt user for issue number

2. **Validate labels:**
    - Check workflow stage labels: `improve-issue`, `blocked`, `needs-discussion`, `plan`, `in-progress`
    - Check type label: `kickoff`, `build`, `fix`, `docs`, `refactor`, `chore`
    - Warn about missing or conflicting labels

3. **Label-driven response:**

   **`improve-issue` label:**
    - Stop and recommend: "Run `/github:issue-improver {number}` before starting work"

   **`blocked` label:**
    - Identify blockers from issue body/comments
    - Recommend: "Resolve blockers before starting"

   **`needs-discussion` label:**
    - Recommend: "Collaborate with user before proceeding"

   **`in-progress` label:**
    - Check status and progress
    - Suggest: "Review progress or switch tasks"

4. **Type-based fidelity analysis:**

   **`kickoff` issues:**
    - Check: Planning completeness, sub-issues created?
    - Focus: High-level structure vs implementation details

   **`build` issues:**
    - Check: Tasks, acceptance criteria, file references, design decisions
    - Focus: Can code be written directly from this?

   **`fix` issues:**
    - Check: Bug description, reproduction steps, root cause, fix approach
    - Focus: Can bug be located and fixed?

   **`docs` issues:**
    - Check: Documentation scope, structure, target location
    - Focus: Clear documentation requirements?

5. **Dependency check:**
    - Find "depends on #X" or "blocked by #X" references
    - Check if related issues are completed
    - Verify referenced files/docs exist
    - Note parent/child issue relationships

6. **Fidelity assessment:**
    - **High:** Ready to build directly - clear specs, acceptance criteria, context
    - **Medium:** Need planning collaboration - some gaps, clarification needed
    - **Low:** Need significant work - missing context, unclear objectives

7. **Provide work readiness summary:**
    - Fidelity level and reasoning
    - Recommended approach: "Build directly" / "Plan first" / "Clarify requirements" / "Fix labels" / "Improve issue"
    - List of suggested files to read (scratchpads, related docs)
    - Blockers or dependencies to resolve
    - Next step recommendation

## Output Format:

Direct to chat (no sandbox needed - this is analysis)

**Writing style:**

- Concise, actionable analysis
- Clear visual indicators (✅ ⚠️)
- Bulleted summaries
- Direct recommendations
