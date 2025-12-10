# Dev Workspace

A structured development environment for AI-assisted coding sessions. Provides context persistence, searchable conversation history, automated workflows, and merge-safe branch management.

## Why Use This?

**Problem:** AI conversations are ephemeral. Context is lost between sessions. You repeat yourself. Discoveries vanish.

**Solution:** Dev Workspace creates a persistent, searchable knowledge base that travels with your feature branch:

- **Context persists** - Discoveries, plans, and decisions survive across sessions
- **History is searchable** - Find that solution you discussed three weeks ago
- **Workflows are automated** - Session startup loads context; session end saves transcripts
- **Merges are safe** - Archive before merge, validate before push

## Quick Start

```bash
# 1. Create a new workspace (creates branch + workspace structure)
/workspace:new-workspace "Add user authentication"

# 2. Work normally - context loads automatically each session

# 3. When done, merge safely
/workspace:merge-preflight    # Validate everything
/workspace:merge-branch       # Execute merge
```

## Directory Structure

```
dev/
├── workspace/                 # Active workspace (on feature branch)
│   ├── WORKSPACE.md          # Configuration (merge strategy, post-merge actions)
│   ├── CLAUDE.md             # Discoveries and guidance for AI
│   ├── context/              # Codebase understanding
│   │   ├── discover.md       # Discovery session outputs
│   │   └── tree.md           # Auto-updated directory tree
│   ├── filebox/              # Scratch files and notes
│   ├── history/              # Conversation transcripts (searchable)
│   ├── plans/                # Planning documents (PRD, architecture)
│   ├── prompts/              # Reusable prompt templates
│   ├── research/             # Web research outputs
│   ├── reviews/              # Code review artifacts
│   └── tasks/                # Task tracking
│       └── user_tasks.md     # Your todo list
└── branches/                  # Archived workspaces (preserved after merge)
    └── YYMMDD_type_description/
```

## Installation

### Prerequisites

- Ruby 3.0+
- [claude_hooks](https://github.com/gabriel-dehan/claude_hooks) gem

```bash
gem install claude_hooks
```

### Directory Setup

1. Copy the `dev/workspace/` template to your repository
2. Copy `.claude/hooks/` directory structure
3. Copy `.claude/commands/workspace/` slash commands
4. Copy `.claude/config/config.json` context configuration

### Hook Configuration

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/entrypoints/session_start.rb"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/entrypoints/user_prompt_submit.rb"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/entrypoints/session_end.rb"
          }
        ]
      }
    ]
  }
}
```

### Context Configuration

Create `.claude/config/config.json`:

```json
{
  "contextPreLoad": [
    "dev/workspace/WORKSPACE.md",
    "dev/workspace/CLAUDE.md",
    "dev/workspace/context/tree.md"
  ],
  "preLoadBegin": "Loading project context files...",
  "preLoadSeparator": "\n\n------- Context File -------\n",
  "preLoadEnd": "\n✓ Context loaded successfully",
  "treeFolders": [
    "dev",
    "docs",
    "app",
    "config",
    "db",
    "lib",
    "test"
  ],
  "treeExcludePatterns": [
    "*.svg",
    "*.jpg",
    "*.webp"
  ],
  "treeOutputPath": "dev/workspace/context/tree.md"
}
```

## Hooks System

### Automatic Behaviors

**Session Start:**

- Loads workspace context files (WORKSPACE.md, CLAUDE.md, tree.md)
- Updates directory tree structure

**Session End:**

- Extracts conversation transcript from JSONL
- Auto-renames file with semantic name (e.g., `25-11-28_user-auth-implementation.txt`)
- Adds searchable summary section

### Keyword Triggers

Type these phrases in your prompt to trigger specialized behaviors:

| Trigger             | Purpose                                                                       |
|---------------------|-------------------------------------------------------------------------------|
| `show working`      | Structured task breakdown: My Task → My Thinking → Issues → Placement/Pattern |
| `show strategy`     | Explore process and approach options before acting                            |
| `show context`      | Reveal what knowledge sources and files are needed                            |
| `show options`      | Explore solution alternatives (Basic/Advanced/Alternative/Unusual)            |
| `show difficulties` | Meta-analysis of conversation quality and communication issues                |
| `use claude space`  | Session-level thinking space for meta-reasoning                               |

**Behavior:** Triggers inject context for one turn only, then revert to normal output style.

## Slash Commands

| Command                              | Description                                    |
|--------------------------------------|------------------------------------------------|
| `/workspace:new-workspace <purpose>` | Create feature branch with workspace structure |
| `/workspace:discover <prompt>`       | Explore codebase using specialized agent       |
| `/workspace:research <prompt>`       | Web research via general-purpose agent         |
| `/workspace:tree`                    | Manually update directory tree                 |
| `/workspace:context-files`           | Load critical context files                    |
| `/workspace:archive-workspace`       | Create snapshot in `dev/branches/`             |
| `/workspace:merge-preflight`         | Validate branch readiness with detailed report |
| `/workspace:merge-branch`            | Execute PR merge after validation              |
| `/workspace:rename-history <file>`   | Rename UUID history file to semantic name      |
| `/workspace:prune-history <file>`    | Manage history files                           |

## Prompt Templates

XML-based templates in `prompts/` for structured planning:

- **`plan.xml`** - High-fidelity feature planning
- **`task.xml`** - Single task execution
- **`fix.xml`** - Bug fix with constraint tracking

### Action DSL

Templates use action attribution to define ownership:

| Action                | Meaning                      |
|-----------------------|------------------------------|
| `User Input`          | User provides raw content    |
| `User Defined`        | User sets requirements       |
| `Collaborate`         | Joint human-AI work          |
| `Assistant Manages`   | AI-driven ownership          |
| `Assistant Decides`   | AI determines if/how to fill |
| `Assistant Discovery` | AI researches independently  |

**Fallback chains:** `? User Defined → Collaborate → Assistant Discovery`

### Template Lifecycle

1. Copy template to working location
2. Rename descriptively (e.g., `plan-user_authentication.xml`)
3. Fill sections progressively per action ownership
4. Persist as project documentation
5. Resume across sessions

## Merge Workflow

Three-command workflow for safe merges:

### 1. Archive (Optional)

```bash
/workspace:archive-workspace
```

Creates snapshot in `dev/branches/YYMMDD_type_description/`. Use for:

- Milestone snapshots during long branches
- Before risky refactors
- Preserving context for future reference

### 2. Preflight Validation

```bash
/workspace:merge-preflight
```

Validates:

- Task completion status
- WORKSPACE.md configuration
- Git state (clean tree, pushed commits)
- PR status (exists, not draft, CI passing)

Generates report in `dev/workspace/reviews/merge-preflight.md`:

- ✅ **PASSED** - All good
- ⚠️ **ATTENTION REQUIRED** - Warnings, may proceed
- ❌ **BLOCKING ISSUES** - Must fix before merge

### 3. Merge Execution

```bash
/workspace:merge-branch
```

- Requires clean preflight report
- Merges PR with configured strategy
- Asks confirmation before branch deletion
- Switches to main and verifies

## Configuration

### WORKSPACE.md Settings

```markdown
### Merge Strategy

- [x] Squash merge
- [ ] Rebase merge
- [ ] Merge commit

### Post-Merge

- [x] Delete branch after merge
- [x] Archive workspace upon merge

### Workflow Type

- [ ] Quick (direct implementation)
- [x] Single plan (plan once, execute)
- [ ] Multi-stage plan (iterative planning)

### Testing

- [x] Requires testing

### Plans currently available

- [x] dev/workspace/plans/prd.md
- [ ] dev/workspace/plans/architecture.md
```

## Searching History

### File Naming Convention

History files use format: `YY-MM-DD_descriptive-name.txt`

Example: `25-11-28_user-auth-implementation.txt`

### Summary Format

Each history file contains a searchable summary:

```
[SUMMARY]
>>>
"Brief description of what was discussed and accomplished"
<<<
```

### Finding Past Context

```bash
# Search summaries
grep -r "authentication" dev/workspace/history/

# Search all history content
grep -rn "specific function" dev/workspace/history/

# List recent files
ls -lt dev/workspace/history/ | head -20
```

## Git Protection

### Template Preservation

Add to `.gitattributes` on main branch:

```
dev/workspace/** merge=ours
```

This prevents feature branches from overwriting the workspace template when merged.

### Merge Procedure

**Before merging to main:**

1. Remove the `dev/workspace/** merge=ours` line from `.gitattributes` on your feature branch
2. Merge the branch
3. Re-add the protection line while on main

The preflight command validates this automatically.

## Troubleshooting

### Context Not Loading

1. Check `.claude/config/config.json` exists with valid JSON
2. Verify paths in `contextPreLoad` array
3. Check hook configuration in `.claude/settings.json`

### History Not Saving

1. Verify session_end hook is configured
2. Check write permissions on `dev/workspace/history/`
3. Ensure `claude_hooks` gem is installed

### Triggers Not Working

1. Include exact trigger phrase (e.g., "show working")
2. Check handler exists in `.claude/hooks/handlers/user_prompt_submit/`
3. Verify corresponding context file in `.claude/hooks/context/`

## File Locations

| Purpose               | Location                      |
|-----------------------|-------------------------------|
| Slash commands        | `.claude/commands/workspace/` |
| Hook handlers         | `.claude/hooks/handlers/`     |
| Hook entrypoints      | `.claude/hooks/entrypoints/`  |
| Trigger context files | `.claude/hooks/context/`      |
| Context config        | `.claude/config/config.json`  |
| Settings              | `.claude/settings.json`       |
| Active workspace      | `dev/workspace/`              |
| Archived workspaces   | `dev/branches/`               |

## Contributing

This system is designed to be portable. To adapt for your repository:

1. Fork the workspace structure
2. Customize `config.json` for your directory layout
3. Modify `WORKSPACE.md` template for your workflow
4. Add project-specific slash commands as needed

## License

MIT
