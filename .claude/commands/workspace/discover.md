---
name: discover
description: Discover codebase context.
argument-hint: <@discover-prompt>
---

Your focus is **discovery**. Your mission: **curate perfect file selections** and **codebase context** for the next model. Do not implement — focus entirely on context discovery and handoff.

**CRITICAL: The Selection Is The Universe**
The files you select become the next model's entire world. The next model likely will NOT have tool access—they only see what you curate. When in doubt, include rather than exclude — better to have too much context than leave the model blind to critical dependencies.

**Your Tools**
Use the `Task(general-purpose)` tool to explore the codebase. Guide the agent using the discovery workflow outlined below.

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

**Ask the Task(general-purpose) agent to:**

- run `tree dev/workspace -I "commands" --dirsfirst`
- Explore the dev workspace reading any plans, context, research, reviews and the CLAUDE.md (for the purpose statement)

### 2) **Locate Relevant Context**

Based on the user's context and workspace understanding, the Task(general-purpose) agent should explore comprehensively:

**Documentation:**

- Check for README and strategic CLAUDE.md files.
- Look for curated reference docs in `/docs`
- Review any design documents or ADRs

**Related Files:**

- Search for files mentioned in the user's request or workspace context
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

**Ask the Task(general-purpose) agent to:**

Map how different parts of the codebase connect:

- Which files import/require each other?
- What protocols/interfaces are being implemented?
- How does data flow through the system?
- What are the key architectural boundaries?

### 4) **Identify Ambiguities**

**Ask the Task(general-purpose) agent to:**

Note any genuine ambiguities or design decisions that need clarification:

- Conflicting patterns in the codebase
- Multiple possible approaches that exist
- Unclear requirements in the user's request
- Technical constraints that might affect implementation

**Stay factual:** Don't propose solutions, just observe what's unclear.

---

## Output: The Discover Report

Once the exploration is complete. Save the Task(Explore) agent's report to `dev/workspace/context/discover.md` using the write tool.

If a `discover.md` file exists create a new file appended with a word or two that is unique and distills the users' context.

**example**
`discover-database-updates.md`

---

## Report Guidelines

**selected_context:**

- One concise line per file explaining what it is and why it matters
- Focus on symbols (classes, functions, components) and their roles
- Mention key functionality or patterns
- Example: "auth/login_controller.rb: LoginController - handles authentication, creates sessions, validates credentials"

**relationships:**

- Explain how files connect and depend on each other
- Use simple arrows or plain language
- Focus on data flow and architectural boundaries
- Help the next model understand the system holistically

**ambiguities:**

- Only include genuine ambiguities or design decisions
- Stay factual - describe what you observed, don't propose solutions
- If everything is clear, write "None"

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
✅ The Discover document includes all necessary files
✅ Relationships map how pieces connect
✅ Ambiguities (if any) are clearly documented
✅ No solutions proposed, no implementation details suggested

---

Remember: You are the scout who maps the territory. The next model depends entirely on the discover document you create. Don't solve the problem—provide complete context so the next model can choose their own solution approach.
