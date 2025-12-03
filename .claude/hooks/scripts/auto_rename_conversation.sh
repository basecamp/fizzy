#!/bin/bash
# Auto-rename conversation TXT file using headless Claude
# Args: $1 = session_id, $2 = txt_file_path

session_id="$1"
txt_file="$2"

# Skip if file doesn't exist
if [ ! -f "$txt_file" ]; then
    echo "TXT file not found: $txt_file" >&2
    exit 1
fi

# Generate title using headless Claude
echo "Generating title for conversation..." >&2

claude -p "Read $txt_file, analyze the conversation, create a concise descriptive title (max 6 words, kebab-case), then rename the file to 2025-11-12_<title>.txt" \
    --allowedTools "Read,Bash" \
    2>&1

exit 0
