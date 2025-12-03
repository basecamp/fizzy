---
name: research
description: Research external context using web search.
argument-hint: <@research-prompt>
---

Your focus is **external research**. Your mission: **gather comprehensive context from web sources** to inform implementation decisions. Do not implement — focus entirely on research, synthesis, and documentation.

**CRITICAL: The Research Is The Foundation**
The research you gather becomes the foundation for informed decision-making. The next model (or the user) will rely on your findings to choose implementation approaches, understand trade-offs, and avoid pitfalls. When in doubt, go deeper — better to have thorough research than leave gaps in understanding.

**Your Tools**

Use the `Task(general-purpose)` Tool to delegate research to an agent. The general-purpose agent will:

1. **Discover workspace context** by exploring `dev/workspace/` documentation
2. **Conduct web research** using `WebSearch` and `WebFetch` tools
3. **Synthesize findings** into a comprehensive research report

Instruct the agent to follow the research workflow outlined below.

## User's Research Request

### Template Path

$ARGUMENTS

**Your Task:**

1. Read the template file at the path provided above
2. Launch the `Task(general-purpose)` agent with instructions to execute the complete research workflow below
3. Once the agent returns its report, save it to `dev/workspace/research/{topic-slug}.md`

---

## Core Principles

- **Thorough over quick:** Deep research beats surface-level findings
- **Cite everything:** Every claim needs a source URL for verification
- **Multiple sources:** Cross-reference findings across different sources
- **Stay current:** Prioritize recent content (check dates, prefer 2024-2025)
- **Context awareness:** Filter findings through the project's specific context and constraints
- **Objective synthesis:** Present findings factually, note trade-offs without bias
- **Question-driven:** Keep the user's specific questions front and center

---

## The Research Workflow

**IMPORTANT:** The `Task(general-purpose)` agent will execute all steps below autonomously. Pass this entire workflow to the agent.

### 1) **Discover Workspace Context**

Start by understanding the workspace:

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

Read and understand the template completely:

- What is the core research goal?
- What keywords and sources should guide searches?
- What specific questions need answers?
- What output format is requested?

### 3) **Engineer Search Queries**

Based on the template and workspace context, create targeted search queries:

**General Strategy:**

- Start broad, then narrow based on findings
- Combine project context with research topic
- Include version numbers for framework-specific searches
- Use "best practices", "patterns", "2024", "2025" to get current recommendations

**Example Query Engineering:**

- Template goal: "Rails 8 authentication patterns"
- Project context: "Rails 8, magic links, invitations"
- Queries:
    - "Rails 8 authentication best practices 2024"
    - "Rails magic link authentication implementation"
    - "Rails passwordless authentication patterns"
    - "Rails 8 has_secure_token authentication"

### 4) **Conduct Web Research**

Use `WebSearch` and `WebFetch` systematically:

**Search Strategy:**

- Run multiple searches covering different angles
- Follow up on promising results with `WebFetch` for details
- Cross-reference findings across multiple sources
- Check official documentation first, then blogs/tutorials
- Look for code examples and real-world implementations

**Source Prioritization:**

- Official docs (framework, library)
- Well-known technical blogs (if mentioned in template)
- GitHub repos with good stars/activity
- Recent Stack Overflow discussions
- Technical community sites (DEV.to, etc.)

**Depth Guidelines:**

- For each key finding, verify across 2-3 sources
- Extract specific code examples where relevant
- Note version compatibility and requirements
- Identify common pitfalls and anti-patterns

### 5) **Synthesize Findings**

Organize findings by:

**Key Insights:**

- Major patterns or approaches discovered
- Consensus views across multiple sources
- Recent developments or changes

**Trade-offs:**

- Different approaches and their pros/cons
- Performance implications
- Complexity vs capability trade-offs
- Community adoption and support

**Best Practices:**

- Recommended patterns from authoritative sources
- Security considerations
- Testing approaches
- Common gotchas to avoid

**Project-Specific Relevance:**

- How findings apply to the specific project context
- Which approaches fit the project's constraints
- Integration considerations with existing architecture

### 6) **Answer Specific Questions**

**The general-purpose agent should address each question in the template:**

- Provide a clear, direct answer
- Support with citations (URLs)
- Note any caveats or context-dependencies
- Flag if more research is needed

---

## Output: The Research Report

Once the exploration is complete. Save the Task(Explore) agent's report to `dev/workspace/research/{topic-slug}.md` using the write tool.

Where `{topic-slug}` is a kebab-case version of the research goal (e.g., "authentication-patterns").

The agent should use the output requirements from the template to structure the report.

---

## Report Structure

Adapt based on template's output requirements, but generally include:

### Executive Summary

[2-3 paragraphs synthesizing the research and key recommendations]

### Research Goal & Context

[Restate the goal and relevant project context from template]

### Findings

#### [Category 1 - Based on Research]

[Detailed findings with citations]

**Sources:**

- [Title](URL) - Brief relevance note
- [Title](URL) - Brief relevance note

#### [Category 2]

[Continue...]

### Best Practices

[If requested in template]

- **Practice 1:** Description
    - Source: [Title](URL)
    - Relevance: How it applies to project

### Code Examples

[If requested in template]

```language
// Example code from research
// Source: URL
```

### Trade-off Analysis

[If requested in template]

| Approach | Pros | Cons | Use When |
|----------|------|------|----------|
| A        | ...  | ...  | ...      |
| B        | ...  | ...  | ...      |

### Answers to Specific Questions

**Q1: [Question from template]**
[Answer with citations]

**Q2: [Question from template]**
[Answer with citations]

### Codebase Integration Considerations

[If requested in template]

[How to apply findings to the specific project]

### Implementation Roadmap

[If requested in template]

1. [Step based on research]
2. [Step based on research]

### Related Resources

**Essential Reading:**

- [Title](URL) - Why it's essential

**Additional References:**

- [Title](URL)
- [Title](URL)

### Open Questions

[Gaps in research, areas needing clarification, or questions that emerged during research]

---

## Research Quality Guidelines

**Citations:**

- Every claim needs a source URL
- Include publication date where visible
- Note if source is official documentation vs blog/tutorial
- Link directly to relevant section when possible

**Currency:**

- Prefer sources from 2024-2025
- Note if information might be outdated
- Check for framework version compatibility
- Flag deprecated approaches

**Depth:**

- Don't just summarize — synthesize and analyze
- Explain *why* certain approaches are recommended
- Include both what to do AND what to avoid
- Provide enough detail for informed decision-making

**Objectivity:**

- Present multiple approaches fairly
- Note trade-offs without pushing one solution
- Distinguish between opinion and consensus
- Flag when sources disagree

---

## Anti-patterns to Avoid

🚫 **Shallow searches** - Don't stop at first result, dig deeper
🚫 **Single source** - Cross-reference findings across multiple sources
🚫 **Missing citations** - Every finding needs a URL
🚫 **Ignoring dates** - Check if information is current
🚫 **Generic advice** - Filter findings through project's specific context
🚫 **Implementation bias** - Don't favor one approach without presenting alternatives
🚫 **Copying blindly** - Synthesize and analyze, don't just paste quotes
🚫 **Ignoring questions** - Address every specific question from template

---

## Success Criteria

✅ All specific questions from template are answered with citations
✅ Multiple authoritative sources consulted for key findings
✅ Trade-offs and alternatives are clearly documented
✅ Findings are filtered through project-specific context
✅ Report is well-organized and follows template's output requirements
✅ Sources are recent, relevant, and properly cited
✅ Best practices and anti-patterns are clearly identified
✅ Report provides actionable insights for implementation decisions

---

Remember: You are the researcher who gathers external wisdom. The next phase depends on having comprehensive, well-cited, context-aware findings. Don't rush to implement — provide thorough research that enables informed decision-making.
