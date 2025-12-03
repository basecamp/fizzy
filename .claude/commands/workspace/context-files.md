---
name: context-files
description: Discover codebase context.
allowed-tools: bash(tree)
---

Your focus is **Discovery**. Your mission: **curate the perfect file selection** for the next model. Do not implement — focus entirely on context discovery and handoff.

**CRITICAL: The Selection Is The Universe**
The files you select become the next model's entire world. The next model likely will NOT have tool access—they only see what you curate. When in doubt, include rather than exclude—better to have too much context than leave the model blind to critical dependencies.

**Your Tools**
Use the `Task(Explore)` tool on medium thoroughness, to explore the codebase. guide the agent using the discovery workflow outlined below.

## Users Context

### Prompt

$ARGUMENTS

---

## Core Principles

- **The next model is isolated:** They see only what you select, nothing more
- **Don't assume a solution:** Select context that enables different approaches, not just your imagined solution
- **Think like a different model:** Include complete context around the problem area, not just what you think needs changing
- **Resolve ambiguity now:** Clarify task scope and context during exploration
- **Stay factual:** Do NOT propose solutions or implementation approaches
- **Look everywhere:** Be thorough and comprehensive. The goal is complete understanding, not efficiency.

---

## The Discovery Workflow

### 1) **Understand Workspace**

Start by getting a comprehensive view of the workspace:

**Ask the Task(Explore) agent to:**

- run the `tree dev/workspace -I "commands" --dirsfirst` bash command.
- Explore the dev workspace reading any plans, context, reviews and tasks.

### 2) **Locate Relevant Context**

Based on the user's context, explore comprehensively:

**Documentation:**

- Look for curated reference docs in `/docs`
- Review any design documents or ADRs

**Related Files:**

- Search for files mentioned in the user's request
- Find files that import/require the mentioned files
- Trace dependencies both upstream and downstream

**Applicable Code:**

- Find related classes, modules, functions
- Examine configuration files (config/, .env, etc.)
- Review stylesheets, components, templates as relevant
- Check test files for usage examples

**Patterns and Conventions:**

- Identify coding patterns used in the project
- Note naming conventions
- Observe architectural patterns (MVC, component-based, etc.)

**Be thorough:** This is your only chance to gather context. The next model cannot explore further.

### 3) **Understand Relationships**

Map how different parts of the codebase connect:

- Which files import/require each other?
- What protocols/interfaces are being implemented?
- How does data flow through the system?
- What are the key architectural boundaries?

---

## Output: The Context Report

Once the exploration is complete. Save the Task(Explore) agent's report to `dev/workspace/context/CONTEXT.md` using the write tool.

---

## Context Document Guidelines

**file_refs:**

- Use `@path/to/file` syntax
- Include ALL files that are relevant to understanding the problem space
- When the next model opens this document, these files auto-load into context
- Order doesn't matter, but group related files if it helps readability

**code_snippets:**

- Use !`command` syntax
- Include ALL code snippets that are relevant to understanding the problem space
- When the next model opens this document, these snippets auto-execute

**curated_docs:**

- Use `@path/to/doc` syntax for full doc files
- Use !`command` for partial snippets
- Include ALL curated docs that are relevant to understanding the problem space
- When the next model opens this document, these docs auto-load into context

**tree_commands:**

- Use `tree -L [depth] path/to/dir` syntax
- Include tree commands for directories that need structural context
- When the next model opens this document, these commands auto-execute
- Typical depths: 2-3 levels for most directories

**sort_files_&_snippets:**

- Order files and snippets into importance categories.
    - Core
    - Important
    - Supporting
    - Doc Snippets
- Base this sorting on the files importance to the task at hand.

---

## Anti-patterns to Avoid

🚫 **Assuming a solution** - Don't only include context for one implementation approach
🚫 **Proposing implementations** - Stay descriptive, not prescriptive
🚫 **Narrow selection** - Include complete context, not just the files you think need changing
🚫 **Missing dependencies** - If FileA imports FileB, include both
🚫 **Forgetting documentation** - READMEs and design docs are valuable context
🚫 **Skipping tests** - Test files often reveal usage patterns and edge cases
🚫 **Under-exploring** - Be thorough, tokens don't matter during discovery

---

## Success Criteria

✅ Comprehensive exploration of all relevant code
✅ Handoff document includes all necessary files as `@file` references
✅ Tree commands provide structural context via !`tree` commands
✅ No solutions proposed, no implementation details suggested

---

Remember: You are the scout who maps the territory. The next model depends entirely on the handoff document you create. Don't solve the problem—provide complete context so the next model can choose their own solution approach.

The `@file` and !`command` references in your output will automatically load context when the document is opened, so include everything the next model will need to understand and solve the problem.
