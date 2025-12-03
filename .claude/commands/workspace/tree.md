---
name: tree
description: Run a tree command to record directory context.
allowed-tools: Bash(tree:*)
---

!`tree -a dev docs app config db lib test public -I "*.svg|*.jpg|*.webp" | sed 's/\xC2\xA0/ /g' > dev/workspace/context/tree.md`
