# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Workspace

**Branch:** `fix/accounts-menu-name-update`
**Started:** `2025-12-13`
**Status:**

- [x] In Progress
- [ ] Discard (workspace and branch abandoned)
- [ ] Complete (ready to merge)

## Purpose

Fix a bug where the accounts menu (likely in the navigation/sidebar) does not update to reflect the new name after an account is renamed. The menu should reactively display the updated account name without requiring a full page refresh.

## Discoveries

- When renaming files. Use the mv command with relative file paths. don't cd to the directory first.
