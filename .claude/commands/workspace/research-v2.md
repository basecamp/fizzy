---
name: research-v2
description: Research external context using web search (v2 - prepared search).
argument-hint: <@research-prompt>
---

Your focus is **external research**. Your mission: **prepare targeted research instructions** based on workspace context, then delegate web research to an agent.

**CRITICAL: Context-Aware Search Engineering**
You understand the workspace and project. Use this knowledge to engineer precise, targeted search queries that the agent will execute. The better your search strategy, the more relevant the research findings.

**Your Tools**

You will use the `Task(general-purpose)` Tool to delegate web research to an agent, but first you must prepare the research strategy.

## User's Research Request

### Template Path

$ARGUMENTS

---

## Your Workflow

### 1) **Understand Workspace Context**

Gather context before engineering searches:

- Run `tree dev/workspace -I "commands" --dirsfirst` to see workspace structure
- Explore `dev/workspace/` focusing on:
    - `plans/` - implementation plans and strategies
    - `context/` - discovered codebase context
    - `research/` - existing research findings
    - `reviews/` - reviews and analysis
- Read root `CLAUDE.md` for project architecture and technologies

Extract key context:

- What is the project tech stack? (Framework, language, libraries)
- What is the current workspace working on?
- What are the architectural patterns and constraints?
- What conventions should be followed?

### 2) **Parse Research Template**

Read the template file at the path provided above and understand:

- What is the core research goal?
- What keywords and sources should guide searches?
- What specific questions need answers?
- What output format is requested?
- Why is this research needed?

### 3) **Engineer Search Strategy**

Based on workspace context + template, create a detailed search strategy:

**Search Queries:**

Create 5-10 specific search queries that combine:

- Start broad, then narrow based on findings
- Combine project context with research topic
- Include version numbers for framework-specific searches
- Include search terms that pick up current recommendations

**Research Focus:**

Based on template questions and workspace needs, specify:

- What specific information to extract
- What trade-offs to analyze
- What code examples to look for
- What compatibility/version requirements matter
- Specific sources to target

### 4) **Launch Research Agent**

Launch the `Task(general-purpose)` agent with:

**Instructions to agent:**

```
You are conducting web research on: [RESEARCH GOAL]

Project Context:
- Tech stack: [FROM WORKSPACE]
- Current work: [FROM WORKSPACE]
- Constraints: [FROM WORKSPACE]

Execute these search queries:
1. [QUERY 1]
2. [QUERY 2]
...

Source priorities:
- [SOURCE 1]
- [SOURCE 2]
...

For each search result:
- Use WebSearch to find relevant sources
- Use WebFetch to extract detailed information
- Cross-reference findings across 2-3 sources
- Note publication dates and verify currency

Focus on extracting:
- [SPECIFIC INFO 1]
- [SPECIFIC INFO 2]
...

Answer these specific questions:
1. [QUESTION 1 FROM TEMPLATE]
2. [QUESTION 2 FROM TEMPLATE]
...

Structure your findings report with:
[OUTPUT REQUIREMENTS FROM TEMPLATE]

Return a comprehensive research report with:
- Executive summary
- Detailed findings with citations (URLs + dates)
- Best practices relevant to our tech stack
- Code examples where applicable
- Trade-off analysis of different approaches
- Answers to all specific questions
- Integration considerations for our project
- Open questions or gaps in research
```

### 5) **Review & Save Report**

Once the agent returns its report:

- Review findings for quality and relevance
- Verify citations are present and accessible
- Ensure all template questions are answered
- Check that findings are filtered through project context
- Save the report to `dev/workspace/research/{topic-slug}.md`

Where `{topic-slug}` is a kebab-case version of the research goal (e.g., "authentication-patterns").

---

## Core Principles

- **Context-driven queries:** Use workspace knowledge to create targeted searches
- **Specific over generic:** Engineer precise queries, not broad ones
- **Quality sources:** Guide agent to authoritative, current sources
- **Question-focused:** Ensure agent addresses all template questions
- **Project-relevant:** Filter everything through workspace context

---

## Research Quality Guidelines

**For Search Strategy:**

- Combine project tech + research topic in queries
- Include version numbers for framework-specific searches
- Use quality signals ("best practices", "2024", "2025")
- Target official docs + reputable community sources

**For Agent Instructions:**

- Be specific about what information to extract
- List exact questions that need answers
- Specify output format from template
- Emphasize cross-referencing multiple sources

**For Final Report:**

- Every claim needs a source URL
- Prefer current sources
- Synthesize findings, don't just quote
- Filter through project's specific context
- Present trade-offs objectively

---

## Success Criteria

✅ Search strategy incorporates workspace context
✅ Queries are specific and targeted to tech stack
✅ Agent receives clear, detailed instructions
✅ All template questions are addressed
✅ Findings are relevant to project constraints
✅ Multiple authoritative sources cited
✅ Report includes actionable insights
✅ Trade-offs and alternatives documented

---

Remember: You are the research strategist who prepares the mission. Your workspace knowledge enables targeted, relevant research. Engineer precise searches so the agent gathers exactly what's needed.
