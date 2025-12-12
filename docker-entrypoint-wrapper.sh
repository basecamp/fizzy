#!/bin/bash
set -e

# Fix ownership and permissions of volume mounts if running as root
if [ "$(id -u)" = "0" ]; then
  echo "Fixing volume permissions..."
  # Ensure directories exist and are writable
  mkdir -p /rails/storage /rails/log /rails/tmp
  chmod -R 755 /rails/storage /rails/log /rails/tmp 2>/dev/null || true
  chown -R rails:rails /rails/storage /rails/log /rails/tmp 2>/dev/null || true
  # Execute as rails user
  echo "Switching to rails user..."
  exec gosu rails /rails/bin/docker-entrypoint "$@"
else
  # Already running as rails user
  exec /rails/bin/docker-entrypoint "$@"
fi
