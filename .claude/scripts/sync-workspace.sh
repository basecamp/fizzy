#!/bin/bash

# Configuration
UPSTREAM_NAME="workspace"
UPSTREAM_URL="https://github.com/dilberryhoundog/dev-workspace.git"
UPSTREAM_BRANCH="main"
CHECKOUT_PATHS=(".claude/" "dev/workspace/")
COMMIT_MSG="🔄 chore: sync workspace from upstream"

# Check if remote exists, add if not
if ! git remote get-url "$UPSTREAM_NAME" &>/dev/null; then
    echo "Adding remote '$UPSTREAM_NAME'..."
    git remote add "$UPSTREAM_NAME" "$UPSTREAM_URL"
fi

# Fetch latest
echo "Fetching from $UPSTREAM_NAME..."
git fetch "$UPSTREAM_NAME"

# Checkout folders (overwrite)
echo "Syncing folders..."
for path in "${CHECKOUT_PATHS[@]}"; do
    git checkout "$UPSTREAM_NAME/$UPSTREAM_BRANCH" -- "$path"
done

# Merge (no commit) for files like Gemfile, .gitignore
echo "Merging..."
git merge "$UPSTREAM_NAME/$UPSTREAM_BRANCH" --no-commit || {
    echo "Merge conflicts detected. Resolve manually then commit."
    exit 1
}

# Commit everything
echo "Committing..."
git commit -m "$COMMIT_MSG"

echo "✅ Sync complete"
