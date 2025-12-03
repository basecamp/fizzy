#!/usr/bin/env python3
"""
Parse Claude Code conversation JSONL files into readable TXT format.
Triggered by SessionEnd hook.
"""

import json
import sys
import os
from pathlib import Path
from datetime import datetime

def parse_conversation(session_data):
    """Parse conversation JSONL and output formatted TXT."""

    # Extract session info from hook input
    session_id = session_data.get('session_id')
    transcript_path = session_data.get('transcript_path')
    cwd = session_data.get('cwd')

    if not transcript_path or not os.path.exists(transcript_path):
        print(f"Error: Transcript not found at {transcript_path}", file=sys.stderr)
        return 1

    # Read JSONL file
    with open(transcript_path, 'r') as f:
        lines = [json.loads(line) for line in f if line.strip()]

    # ============================================================
    # ABORT: Skip headless Claude sessions (queue-operation + sidechain)
    # ============================================================
    for line in lines:
        if line.get('type') == 'queue-operation' or line.get('isSidechain') == True:
            print("Skipping headless/sidechain session")
            return 0

    # Extract metadata from first message
    metadata = {}
    for line in lines:
        if line.get('type') == 'user':
            metadata = {
                'session_id': line.get('sessionId', session_id),
                'timestamp': line.get('timestamp', ''),
                'git_branch': line.get('gitBranch', 'unknown'),
                'cwd': line.get('cwd', cwd)
            }
            break

    # Format output
    output = []
    output.append(f"Session: {metadata.get('session_id', 'unknown')}")

    # Parse timestamp
    ts = metadata.get('timestamp', '')
    if ts:
        dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
        output.append(f"Date: {dt.strftime('%Y-%m-%d %H:%M')}")

    output.append(f"Branch: {metadata.get('git_branch', 'unknown')}")
    output.append(f"CWD: {metadata.get('cwd', 'unknown')}")
    output.append("")
    output.append("=" * 60)
    output.append("")

    # Parse conversation turns
    for line in lines:
        msg_type = line.get('type')

        # Skip file-history-snapshot, queue-operation and other metadata
        if msg_type in ('file-history-snapshot', 'queue-operation'):
            continue

        if msg_type == 'user':
            message = line.get('message', {})
            content = message.get('content', '')

            # Skip tool_result messages (system feedback)
            if isinstance(content, list):
                # Filter out tool_result items
                filtered_items = []
                for item in content:
                    if isinstance(item, dict) and item.get('type') == 'tool_result':
                        continue
                    filtered_items.append(item)

                # Skip if only tool results
                if not filtered_items:
                    continue

                content_text = '\n'.join([item.get('text', str(item)) if isinstance(item, dict) else str(item) for item in filtered_items])
            else:
                content_text = str(content)

            # Skip empty messages
            if not content_text.strip():
                continue

            output.append("[USER]")
            output.append(content_text)
            output.append("")

        elif msg_type == 'assistant':
            message = line.get('message', {})
            content = message.get('content', [])

            # Separate text from tool uses
            text_parts = []
            tool_uses = []

            for item in content:
                if isinstance(item, dict):
                    if item.get('type') == 'text':
                        text_parts.append(item.get('text', ''))
                    elif item.get('type') == 'tool_use':
                        tool_uses.append(item)

            # Output assistant text
            if text_parts:
                output.append("[ASSISTANT]")
                output.append('\n'.join(text_parts))
                output.append("")

            # Output tool summary
            if tool_uses:
                output.append("[TOOLS USED]")
                for tool in tool_uses:
                    name = tool.get('name', 'Unknown')
                    tool_input = tool.get('input', {})

                    # Extract command and description
                    command = tool_input.get('command', '')
                    description = tool_input.get('description', '')

                    if command:
                        output.append(f"- {name}: {command}")
                        if description:
                            output.append(f"  {description}")
                    else:
                        # Non-bash tools
                        output.append(f"- {name}")

                output.append("")

        # Turn separator
        if msg_type in ('user', 'assistant'):
            output.append("-" * 60)
            output.append("")

    # Determine output path
    project_dir = cwd if cwd else os.getcwd()
    output_dir = Path(project_dir) / 'dev' / 'claude' / 'chat-history'
    output_dir.mkdir(parents=True, exist_ok=True)

    # Check if session already exists in any file (resumed conversation)
    existing_file = None
    for txt_file in output_dir.glob('*.txt'):
        try:
            with open(txt_file, 'r') as f:
                first_line = f.readline().strip()
                if first_line == f"Session: {session_id}":
                    existing_file = txt_file
                    break
        except:
            continue

    # Use existing file or create new one
    output_file = existing_file if existing_file else output_dir / f"{session_id}.txt"
    is_new_file = existing_file is None

    # Write output
    with open(output_file, 'w') as f:
        f.write('\n'.join(output))

    if is_new_file:
        print(f"Parsed conversation saved to: {output_file}")
    else:
        print(f"Updated existing conversation: {output_file}")

    # ============================================================
    # AUTO-RENAME: Call headless Claude to generate meaningful filename
    # Only run for NEW files (skip for resumed conversations)
    # ============================================================
    if is_new_file:
        try:
            import subprocess

            rename_script = Path(__file__).parent / 'auto_rename_conversation.sh'

            result = subprocess.run(
                ['bash', str(rename_script), session_id, str(output_file)],
                capture_output=True,
                text=True
            )

            # Print rename output
            if result.stdout:
                print(result.stdout)
            if result.stderr:
                print(result.stderr, file=sys.stderr)

        except Exception as e:
            print(f"Warning: Auto-rename failed: {e}", file=sys.stderr)
            # Don't fail the whole hook if rename fails
    else:
        print("Skipping auto-rename for resumed conversation")
 # ===============
 # end AUTO-RENAME
 # ===============

    return 0

def main():
    """Main entry point for hook."""
    try:
        # Read session data from stdin
        session_data = json.load(sys.stdin)
        return parse_conversation(session_data)
    except Exception as e:
        print(f"Error parsing conversation: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
