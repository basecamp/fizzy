---
name: Rename History
description: Analyze chat history and suggest human-readable filename
allowed-tools: Read, Bash(mv:*)
argument-hint: <history-file-path>
---

Analyze user prompts in chat history file and suggest concise, human-readable filename.

## File Path

@$ARGUMENTS

## Workflow

### Step 1: Read History File

If no file path provided in arguments, prompt: "Provide file path: `/workspace:rename-history dev/workspace/history/file.txt`"

Use Read tool with the provided file path.

### Step 2: Analyze History

Analyze user prompts from file content (ignore assistant responses and system messages).

Extract key themes, topics, or actions discussed across all user turns.

### Step 3: Generate Filename Suggestion

Create short, descriptive filename (3-6 words max):

- Use underscores between words
- Lowercase preferred but Title_Case acceptable
- Describe the actual work/topic, not meta-conversation
- Max ~50 chars
- No special chars except underscores/hyphens
- Must end with `.txt`

Examples:

- `Workspace_Chat_History_Hook.txt`
- `rails_authentication_magic_links.txt`
- `task_completion_photo_upload.txt`

### Step 4: Present Suggestion

```
Suggested filename: {new-name}

Current: {current-filename}
Session ID: {session-id from line 1}

Rename? (yes/no)
```

### Step 5: Execute Rename

On confirmation:

```bash
mv "dev/workspace/history/{current-filename}" "dev/workspace/history/{new-name}"
```

Confirm: "✓ Renamed to {new-name}. Hook will continue appending via session ID."

## Safety

- ⚠️ Preserve session ID in file content (line 1)
- ⚠️ Check for filename conflicts before rename
- ✓ Only rename files in dev/workspace/history/
- ✓ Maintain .txt extension
