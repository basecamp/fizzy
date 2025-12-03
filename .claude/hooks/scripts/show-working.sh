#!/bin/bash
# Hook: show-working
# Detects "show working" or "show your working" in user prompt
# Injects context from show-working.txt when triggered

# Read JSON input from stdin
INPUT=$(cat)

# Parse the prompt field
if echo "${INPUT}" | jq -e . >/dev/null 2>&1; then
  PROMPT=$(echo "${INPUT}" | jq -r '.prompt // empty')

  # Check for "show working" or "show your working" (case-insensitive)
  if echo "${PROMPT}" | grep -iq "show \(your \)\?working"; then
    # Inject instructions from file
    if [ -f "$CLAUDE_PROJECT_DIR/.claude/hooks/show-working.txt" ]; then
      cat "$CLAUDE_PROJECT_DIR/.claude/hooks/show-working.txt"
    fi
  fi

  # ===== ADD MORE TRIGGERS BELOW =====
  # Pattern: Check for trigger phrase(s), then cat the corresponding instruction file
  # Tips:
  # - Use 'elif' for additional triggers (first match wins)
  # - grep -iq = case-insensitive search
  # - Regex: \(optional word\)\? = optional, \| = OR
  # - Create matching .txt file in .claude/hooks/ with instructions
  # - Add self-terminating instructions at end of .txt (see show-working.txt)
  # ===================================

fi

exit 0
