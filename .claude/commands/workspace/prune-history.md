---
name: Prune History
description: Analyze all UUID-named history files, propose prune/rename actions, or execute from prune.md
allowed-tools: Read, Write, Bash(tree:*), Bash(mv:*, rm:*)
argument-hint: <prune.md-path>
---

Dual-purpose command to manage chat history cleanup:

- **No args**: Analyze UUID-named files, generate `prune.md` with keep/delete/rename proposals
- **With prune.md path**: Execute the proposals, then delete `prune.md`

## Mode Detection - IMPORTANT

Check here for arguments --> `$ARGUMENTS` <--

- Empty → **Analysis Mode** (generate prune.md)
- Contains path → **Execution Mode** (process prune.md)

---

## Analysis Mode (No Arguments)

Generate `dev/workspace/history/prune.md` with keep/rename/delete proposals for all UUID-named files.

### Step 1: Find UUID Files

run `tree dev/workspace/history` bash command

Extract UUID-pattern filenames from tree output (format: `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}.txt`)

Skip files with human-readable names (already processed).

### Step 2: Analyze Each File

For each UUID file:

1. Read content (user prompts only, ignore assistant/system)
2. Classify as **KEEP** or **DELETE** based on: **Does this file contain knowledge?**
    - **KEEP**: Any information, discoveries, learnings, context worth preserving
    - **DELETE**: Pure noise with no knowledge value

3. For **KEEP** files: Generate descriptive filename (3-6 words, underscores, lowercase, max 50 chars)
4. For **DELETE** files: Brief reason (1 line)

### Step 3: Generate prune.md

Write to `dev/workspace/history/prune.md`:

```markdown
# History Prune Plan

Generated: {timestamp}

**Instructions:** Review proposals below. Check boxes to KEEP & RENAME files. Unchecked = DELETE.

---

- [ ] 22690afe-0007-4c31-974b-78c7ffc3f92f.txt → single_resume_command.txt
  > Contains only "resume" command - no meaningful content

- [ ] 966f2c27-8b49-4f60-a705-e9e6e09802a4.txt → claude_response_hook_attempt.txt
  > Experimented with stop event hooks for appending Claude responses, ultimately abandoned

- [x] 44a82602-4f37-463e-8ada-2da2a225f370.txt → prune_command_design_discussion.txt
  > Discussed prune-history command design - KEEP for workspace context

---

**To execute:**
`/workspace:prune-history dev/workspace/history/prune.md`
```

### Step 4: Present to User

```
✓ Generated prune.md with {N} files analyzed

{X} marked for deletion
{Y} marked for keep/rename

Review: dev/workspace/history/prune.md
Execute: /workspace:prune-history dev/workspace/history/prune.md
```

---

## Execution Mode (With prune.md Path)

Process proposals in the provided prune.md file.

### Step 1: Read & Parse prune.md

Extract checklist items:

- Checked `[x]` → KEEP & RENAME
- Unchecked `[ ]` → DELETE

Parse format: `- [x] {uuid-filename}.txt → {new-name}.txt`

### Step 2: Execute Deletions

For each unchecked item:

```bash
rm "dev/workspace/history/{uuid-filename}.txt"
```

Track: `✓ Deleted {filename}`

### Step 3: Execute Renames

For each checked item:

```bash
mv "dev/workspace/history/{uuid-filename}.txt" "dev/workspace/history/{new-name}.txt"
```

Track: `✓ Renamed {uuid} → {new-name}`

### Step 4: Delete prune.md

```bash
rm "dev/workspace/history/prune.md"
```

### Step 5: Report Results

```
✓ Pruning complete

Deleted: {N} files
Renamed: {M} files
Removed: prune.md

History cleaned!
```

---

## Safety

- ⚠️ Only process files in `dev/workspace/history/`
- ⚠️ Only delete/rename UUID-pattern files (never human-named)
- ⚠️ Check file existence before mv/rm operations
- ⚠️ Session IDs preserved in file content (line 1)
- ✓ Maintain `.txt` extension
- ✓ Liberal KEEP policy - when uncertain, keep it

## Pruning Philosophy

**Core Question:** Does this file contain knowledge worth preserving?

**KEEP (contains knowledge):**

- Any information, discoveries, learnings, context
- Examples: technical discussions, failed experiments with learnings, architecture explorations, design considerations, problem-solving attempts, constraint discoveries, decision context

**DELETE (no knowledge, just noise):**

- Pure mechanics with no informational value
- Examples: logistics ("resume", "yes", "ok"), single commands with no context, disconnected responses, trivial exchanges

When uncertain whether file contains knowledge → KEEP
