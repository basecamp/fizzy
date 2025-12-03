# Claude Code Configuration

This directory contains Claude Code configuration for this project.

## Slash Commands

### Issue Management

- `/issue-improver <number>` - Analyzes issue structure and suggests improvements. Drafts to `docs/sandbox/issue-{number}-improved.md` for approval. User posts with: `gh issue edit {number} -F docs/sandbox/issue-{number}-improved.md`
- `/issue-plan <number>` - Collaborative planning via issue comments. Drafts to `docs/sandbox/issue-{number}-plan.md` for approval. User posts with: `gh issue comment {number} -F docs/sandbox/issue-{number}-plan.md`
- `/issue-close <number>` - Creates summary comment when closing issue. Drafts to `docs/sandbox/issue-{number}-closure.md` for approval. User posts with: `gh issue close {number} --comment "$(cat docs/sandbox/issue-{number}-closure.md)"`
- `/issue-start <number>` - Analyzes issue readiness and provides orientation before starting work

### PR Management

- `/pr-init <number>` - Assists with PR body improvements after user creates draft. Drafts to `docs/sandbox/pr-{number}-init.md` for approval. User posts with: `gh pr edit {number} -F docs/sandbox/pr-{number}-init.md`
- `/pr-draft-to-ready <number>` - Provides checklist and verification for marking PR ready. User executes `gh pr ready` manually
- `/pr-from-issue <number>` - **(deprecated)** User creates PRs manually

### Development

- `/ruby_scratchpad <feature>` - Model features using Ruby scratchpads
- `/html_scratchpad <page>` - Prototype pages using XML scratchpads
- `/cleanup` - Work through cleanup task list
- `/record_feature` - Document completed feature from git history

### Styling

- `/css:*` - CSS-related commands (see CSS/ subdirectory)

## Output Styles

- `default` - Standard Claude output
- `github-cli` - Concise, markdown-formatted for GitHub comments (currently active)

## Settings Files

- `settings.json` - Project settings (committed, team-wide)
- `settings.local.json` - Personal overrides (gitignored)

### Permissions (settings.json)

**Allow:**

- Git: add, checkout, fetch, pull, -C exploration (diff/show/log/ls-files/status)
- GitHub: issues, labels
- Rails: rails/bundle/rake commands
- Slash commands & skills

**Deny:**

- Rails secrets: .env, master.key, credentials
- Lock files: Gemfile.lock, package-lock.json
- Generated: db/schema.rb
- Git config tampering

**Ask:**

- Git: commit, push
- GitHub: merge, edit, comment
- Rails: db:*, bundle install

### Hooks

**SessionStart:**

1. Generate tree → `dev/workspace/context/tree.md`
2. Load workspace context (WORKSPACE.md, PRD, architectural.md, CLAUDE.md)

### Sandbox (settings.json)

- **Enabled:** Commands run in isolated container
- **autoAllowBashIfSandboxed:** Fewer prompts for allowed commands
- **excludedCommands:** Git runs outside sandbox (needs .git access)
- **allowLocalBinding:** Rails server can bind localhost:3000

**Troubleshooting:** If sandbox causes issues, set `"enabled": false`

## Workflows

Workflows are defined in output style files:

- **github-cli** - User-driven GitHub CLI workflow (`.claude/output-styles/github-cli.md`)
- **rails-progressive** - Progressive enhancement workflow (`.claude/output-styles/rails-progressive.md`)

Workflows are modular and switchable based on project needs.

## GitHub CLI Commands Reference

### Issues

```bash
# View issue details
gh issue view <number>

# Edit issue body from file
gh issue edit <number> -F docs/sandbox/issue-<number>-improved.md

# Add comment from file
gh issue comment <number> -F docs/sandbox/issue-<number>-plan.md

# Close issue with comment from file
gh issue close <number> --comment "$(cat docs/sandbox/issue-<number>-closure.md)"

# List issues
gh issue list --milestone "name"
```

### Pull Requests

```bash
# Create draft PR
gh pr create --draft --base development

# Create regular PR
gh pr create --base development --fill

# Edit PR body from file
gh pr edit <number> -F docs/sandbox/pr-<number>-init.md

# Mark draft PR ready
gh pr ready <number>

# View PR in browser
gh pr view <number> --web

# Merge PR
gh pr merge <number> --squash

# Close PR
gh pr close <number> --comment "reason"
```

## Additional Resources

- **Main docs**: `CLAUDE.md` - Architecture, patterns, and workflows
- **Issue templates**: `.github/ISSUE_TEMPLATE/` - Structured issue creation
- **PR template**: `.github/pull_request_template.md` - PR structure
