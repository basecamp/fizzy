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

**Branch:** `fix/identity-user-destroy-pattern`
**Started:** `2025-12-07`
**Status:**

- [x] In Progress
- [ ] Discard (workspace and branch abandoned)
- [ ] Complete (ready to merge)

## Purpose

Fix and improve how Fizzy handles destroying Identities and Users. The core issue is ensuring proper ordering of callbacks and dependent associations so that user deactivation works correctly before identity links are nullified.

## Key Files

- `app/models/identity.rb` - `before_destroy :deactivate_users, prepend: true`
- `app/models/user.rb` - `User#deactivate` preserves identity link intentionally
- `app/models/identity/joinable.rb` - Reactivation relies on preserved identity link

## Pattern Summary

The destroy/deactivation flow requires careful ordering:
1. Identity#destroy triggers `deactivate_users` callback (prepend: true ensures this runs first)
2. Each user is deactivated (accesses destroyed, marked inactive, connections closed)
3. Only then does `dependent: :nullify` sever the identity link
4. Reactivation via `Identity::Joinable#join` finds existing inactive user by identity


## Discoveries

- **IMPORTANT FOR MERGE**: Before merging this branch to main, remove the `dev/workspace/** merge=ours` line from `.gitattributes` on THIS branch (otherwise merge will be blocked). After merge completes, ADD the protection line to `.gitattributes` while on main branch.

- Use `&CLAUDE_PROJECT_DIR` to access the project directory inside hooks

- When renaming files. Use the mv command with relative file paths. don't cd to the directory first.
