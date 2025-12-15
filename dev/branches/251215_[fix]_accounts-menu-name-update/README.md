# Dev Workspace

A great team-focused workspace ready to shape, build, store and reveal context to claude.

## Installation

### Prerequisites

- Ruby 3.0+
- [claude_hooks](https://github.com/gabriel-dehan/claude_hooks) gem

```bash
gem install claude_hooks
```

### Directory Setup

1. Copy the `dev/workspace/` template to a main or "parent" branch of your repository
2. Overwrite `.claude/` directory in your main or "parent" branch
3. Overwrite with `.gitattributes` and `.gitignore` to the main branch also.

If this causes conflicts, copy sections manually.
I recommend not mixing hook systems.
Use only 'Claude_hooks' or don't use it all.

### Hook Configuration

If you want to maintain your settings. Just copy this section to your settings.json

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

### Git Configuration

Add to `.gitattributes` on Main branch:

```gitattributes
dev/workspace/** merge=ours
.claude/config/** merge=ours
```

Add to `.gitignore` on main branch:

```gitignore
dev/workspace/context/tree.md
```

### Context Configuration

Create `.claude/config/config.json`:
( The tree folders are setup for rails codebases, adjust as needed)

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

## How to get started

### Setup your workspace

- Starting on a clean main or parent branch. Use `/workspace:new-workspace` with a natural language description of what you intend to do with the branch. Claude will then name your new branch and setup your workspace.
- Place the context you want Claude to see for all the work on the branch in `contextPreload:` in `config.json`.
- Adjust the `treeFolders` and `treeExcludePatterns` so that your tree file is not bloated with uneccessary references, before being shown to Claude.

### Lets build!

- Start a new Claude Code terminal session
- Kick off with a starting prompt but at the end say "show your working"
- Claude will stop after showing you all of his working. This is a great opportunity to adjust yuor prompt based on claude response.
- Once you Claude is confident to start building instead hit "show your options".
- Claude will then reveal to you "hidden" options he wouldn't have considered.
- After more back and forth, when again Claude is ready to build, say "show your strategy"
- Claude will then tell you how he is going to implement the changes, revealing more hidden problems and issues.
- Ask claude to "use your claude space" for him to reveal hidden thoughts about how the whole session is progressing.
- Other options include "show your context" to have claude give you all his intended context sources, and "show your difficulties" to have him tell you about the current communication issues in the thread.

### Finishing off

- Once your session is finished, use either `/clear` or `/exit` to end your session.
- The workspace will then extract and format your conversation into the history folder. If renaming fails use the backup command `/workspace:rename-history <file>`
- Commit all changes to the child branch.
- At any time or once your branch is finished enter `/workspace:archive-workspace` to save your workspace as a snapshot in `dev/branches/`, commit to parent branch
- Do `/workspace:merge-preflight` process to prepare branch.
- Finally `/workspace:merge-branch` to merge your changes into the parent branch.

- All the context and conversations you have generated will be preserved permanently, ready to reference or re-use.
