# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Guidance

Workspaces are Claude's primary source of truth. Prioritise searching and revealing workspace knowledge before focusing directly on the codebase. Some important places:

- **/context** - Discoveries, resources, and other contextual information
- **/history** - Conversations with Claude, very useful to run searches in.
- **/plans** - structured planning documents
- **/research** - May contain useful research artifacts
- **/reviews** - May contain reviews of completed work
- **/tasks** - Tasks to complete, may contain instructions for Claude

### Search Chat History

Each Chat History file has a max 5 line summary near the top of the file, and a descriptive file name. These names and summaries can be easily searched using grep, the files are named with a date and the descriptive name, the summary format is:

    [SUMMARY]
    >>>
    "The summary of the conversation is here"
    <<<

# Workspace

**Branch:** `docs/extract-rails-patterns`
**Started:** `2025-12-03`
**Status:**

- [x] In Progress
- [ ] Discard (workspace and branch abandoned)
- [ ] Complete (ready to merge)

## Purpose

[Claude will place a purpose here when you setup the workspace. Below is an example]

Extract and document modern Rails patterns from this OSS Fizzy codebase (37signals/Basecamp). The goal is to identify, catalog, and understand best practices and architectural patterns used in a production-quality Rails application for reference and learning.


## Discoveries

- **IMPORTANT FOR MERGE**: Before merging this branch to main, remove the `dev/workspace/** merge=ours` line from `.gitattributes` on THIS branch (otherwise merge will be blocked). After merge completes, ADD the protection line to `.gitattributes` while on main branch.

- Use `&CLAUDE_PROJECT_DIR` to access the project directory inside hooks

- When renaming files. Use the mv command with relative file paths. don't cd to the directory first.
