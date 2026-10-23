#!/usr/bin/env bash

set -e

# Path segments that carry a credential, filtered from the load balancer's logs as
# proxy.logging.filter_paths in saas/config/deploy.yml filters them on the app hosts.
# Escaped for the remote shell that ssh hands the command to.
log_filters=$(printf -- "--log-filter-path=%q " \
  '/+public/+boards/+([^/]+)' \
  '(?s)/+(?:join|qr_codes|session/+transfers|my/+access_tokens|public/+collections|email_addresses)/+(.+)')

# Beta 1: fizzy-beta-lb-101 -> fizzy-beta-app-101
ssh app@fizzy-beta-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=beta1.fizzy-beta.com \
      --target=fizzy-beta-app-101.df-iad-int.37signals.com
