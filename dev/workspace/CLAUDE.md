# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Guidance

Workspaces are Claude's primary source of truth. Prioritise searching and revealing workspace knowledge before focusing directly on the codebase. Some important places:

- **/context** - Discoveries, resources, and other contextual information
- **/history** - Conversations with Claude, very useful to run searches in.
- **/plans** - structured planning documents
- **/research** - May contain useful research artifacts
- **/reviews** - May contain reviews of completed work

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

Extract and document modern Rails patterns from this OSS Fizzy codebase (37signals/Basecamp). The goal is to identify, catalog, and understand best practices and architectural patterns used in a production-quality Rails application for reference and learning.

## Discoveries

- Use &CLAUDE_PROJECT_DIR to access the project directory inside hooks
- When renaming files. Use the mv command with relative file paths. don't cd to the directory first.
