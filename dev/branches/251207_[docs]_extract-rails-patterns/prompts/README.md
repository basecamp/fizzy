# Prompt Instructions

## Research Prompt

Instructions: Fill out this template and run `/research <@path-to-this-file>`

## Discover Prompt

Instructions: Fill out this template and run `/discover <@path-to-this-file>`

# XML Prompt templates

## Action DSL Reference

The `action=""` attribute on XML template elements defines ownership and completion strategy for each section.

### Action Types

- **User Input** - User provides raw content; assistant doesn't modify
- **User Defined** - User sets requirements; assistant may suggest format
- **Collaborate** - Either party can add/edit; discuss to refine together
- **Assistant Manages** - Assistant owns this section; updates autonomously during work
- **Assistant Decides** - Assistant determines if/how to fill based on context
- **Assistant Checks** - Assistant validates/verifies and updates status
- **Assistant Discovery** - Assistant researches and populates independently

### Fallback Chains

The `?` prefix indicates a priority chain. Try each actor in sequence until one provides content:

```
action="? User Defined -> Collaborate -> Assistant Discovery"
```

Means: User defines first → if empty, collaborate → if still unclear, assistant discovers independently.

### Status Indicators

Inline status tracking within elements:

- `❌` - Open / Not started / Failing
- `✅` - Completed / Passing
- `🚫` - Cancelled / Skipped

### Context Loading

In `<context>` sections:

- `!` prefix - Auto-load files into context
- Pipe in log files, error output, etc.

## Template Lifecycle

1. Copy template from `/prompts` to working location
2. Rename to descriptive name (e.g., `plan-user_authentication.xml`)
3. Fill sections progressively per action ownership
4. Persist as project documentation
5. Resumable across sessions
