#!/bin/bash
# Autoload key files into Claude Code context on session start

echo "Loading project context files..."
echo ""

# Core documentation files
cat << 'EOF'

===== Workspace Configuration =====
EOF

cat dev/workspace/WORKSPACE.md

cat << 'EOF'

===== Specifications =====

EOF

cat dev/workspace/plans/prd.md
echo ""
echo "----- Next File -----"
echo ""
cat dev/workspace/plans/architectural.md

cat << 'EOF'

===== Claude Memory =====
EOF

cat dev/workspace/CLAUDE.md

echo ""
echo "✓ Context loaded successfully"
