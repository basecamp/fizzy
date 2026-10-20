#!/usr/bin/env bash

set -e

# Path segments that carry a credential, filtered from the load balancer's logs as
# proxy.logging.filter_paths in saas/config/deploy.yml filters them on the app hosts.
# Escaped for the remote shell that ssh hands the command to.
log_filters=$(printf -- "--log-filter-path=%q " \
  '/+public/+boards/+([^/]+)' \
  '(?s)/+(?:join|qr_codes|session/+transfers|my/+access_tokens|public/+collections|email_addresses)/+(.+)')

# fizzy-staging-lb-01.sc-chi-int.37signals.com
#
ssh app@fizzy-staging-lb-01.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy-staging.com \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-staging-app-101.df-iad-int.37signals.com \
      --target=fizzy-staging-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-staging-app-01.sc-chi-int.37signals.com \
      --read-target=fizzy-staging-app-02.sc-chi-int.37signals.com

# fizzy-staging-lb-101.df-iad-int.37signals.com
#
ssh app@fizzy-staging-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy-staging.com \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-staging-app-101.df-iad-int.37signals.com \
      --target=fizzy-staging-app-102.df-iad-int.37signals.com

# fizzy-staging-lb-401.df-ams-int.37signals.com
#
ssh app@fizzy-staging-lb-401.df-ams-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy-staging.com \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-staging-app-101.df-iad-int.37signals.com \
      --target=fizzy-staging-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-staging-app-401.df-ams-int.37signals.com \
      --read-target=fizzy-staging-app-402.df-ams-int.37signals.com

# fizzy-staging-lb-501.sjc-int.37signals.com
#
ssh app@fizzy-staging-lb-501.sjc-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy-staging.com \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-staging-app-101.df-iad-int.37signals.com \
      --target=fizzy-staging-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-staging-app-501.sjc-int.37signals.com \
      --read-target=fizzy-staging-app-502.sjc-int.37signals.com
