# Manual Extract Transcript Guide

Quick reference for manually running the extract_transcript hook.

## Command Template

```bash
echo '{"session_id":"SESSION_ID","transcript_path":"{users_home_directory}/.claude/projects/-Users-USERNAME-Projects-cleaning/SESSION_ID.jsonl","cwd":"{project_directory}","reason":"clear","hook_event_name":"SessionEnd"}' | CLAUDE_PROJECT_DIR="{project_directory}" ruby .claude/hooks/handlers/session_end/extract_transcript.rb
```

## Steps

1. **Get session ID** - Check UUID filename in `dev/workspace/history/`
2. **Replace placeholders**:
   - `SESSION_ID` - Session UUID (appears 2x)
   - `{users_home_directory}` - Your home path (e.g., `/Users/username`)
   - `{project_directory}` - Project root path (appears 2x)
   - `USERNAME` - Your username in transcript path
3. **Run command** - From project root
4. **Check logs** - `tail -30 ~/.claude/logs/hooks/session-SESSION_ID.log`
5. **Verify output** - Updated file in `dev/workspace/history/`

## Example

```bash
# Session: 738339c7-5090-49a7-bfb7-627f359ae2af
# Replace {users_home_directory}, {project_directory}, USERNAME with actual values
echo '{"session_id":"738339c7-5090-49a7-bfb7-627f359ae2af","transcript_path":"/Users/yourname/.claude/projects/-Users-yourname-Projects-cleaning/738339c7-5090-49a7-bfb7-627f359ae2af.jsonl","cwd":"/Users/yourname/Projects/cleaning","reason":"clear","hook_event_name":"SessionEnd"}' | CLAUDE_PROJECT_DIR="/Users/yourname/Projects/cleaning" ruby .claude/hooks/handlers/session_end/extract_transcript.rb
```

## Common Issues

- **Tilde not expanded**: Use full path `/Users/dylangraham/.claude/...`
- **Template errors**: Check logs for ERB rendering failures
- **File not updated**: Verify transcript_path exists and is readable
- **Auto-rename timeout**: Rename runs in background (20s timeout)