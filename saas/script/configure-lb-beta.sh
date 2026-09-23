#!/usr/bin/env bash

set -e

# Cloudflare puts the real client IP in True-Client-IP. Most 37signals apps get that copied into
# X-Forwarded-For by the manage_x_forwarded iRule on the F5s, but fizzy's HTTPS virtual server is
# fastL4 passthrough, so no HTTP iRule can run and every tier behind here logs an internal address
# instead (see the "4xx fizzy returns internal IPs" card).
#
# --client-ip-header makes kamal-proxy trust True-Client-IP for its own access log and for the
# X-Forwarded-For it sends on. --forward-headers is what lets that value reach the app tier's proxy
# and Rails: X-Forwarded-For is dropped by default when the proxy terminates TLS, as it does here.

# Beta 1: fizzy-beta-lb-101 -> fizzy-beta-app-101
ssh app@fizzy-beta-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --force \
      --tls \
      --client-ip-header=True-Client-IP \
      --forward-headers \
      --host=beta1.fizzy-beta.com \
      --target=fizzy-beta-app-101.df-iad-int.37signals.com
