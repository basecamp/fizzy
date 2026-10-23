#!/usr/bin/env bash

set -e

# Path segments that carry a credential, filtered from the load balancer's logs as
# proxy.logging.filter_paths in saas/config/deploy.yml filters them on the app hosts.
# Escaped for the remote shell that ssh hands the command to.
log_filters=$(printf -- "--log-filter-path=%q " \
  '/+public/+boards/+([^/]+)' \
  '(?s)/+(?:join|qr_codes|session/+transfers|my/+access_tokens|public/+collections|email_addresses)/+(.+)')

# fizzy-lb-101.df-iad-int.37signals.com
#
ssh app@fizzy-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com


# fizzy-lb-102.df-iad-int.37signals.com
#
ssh app@fizzy-lb-102.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com


# fizzy-lb-01.sc-chi-int.37signals.com
#
ssh app@fizzy-lb-01.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-app-01.sc-chi-int.37signals.com \
      --read-target=fizzy-app-02.sc-chi-int.37signals.com


# fizzy-lb-02.sc-chi-int.37signals.com
#
ssh app@fizzy-lb-02.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-app-01.sc-chi-int.37signals.com \
      --read-target=fizzy-app-02.sc-chi-int.37signals.com


# fizzy-lb-401.df-ams-int.37signals.com
#
ssh app@fizzy-lb-401.df-ams-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-app-401.df-ams-int.37signals.com \
      --read-target=fizzy-app-402.df-ams-int.37signals.com


# fizzy-lb-402.df-ams-int.37signals.com
#
ssh app@fizzy-lb-402.df-ams-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-app-401.df-ams-int.37signals.com \
      --read-target=fizzy-app-402.df-ams-int.37signals.com

# fizzy-lb-501.sjc-int.37signals.com
#
ssh app@fizzy-lb-501.sjc-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-app-501.sjc-int.37signals.com \
      --read-target=fizzy-app-502.sjc-int.37signals.com


# fizzy-lb-502.sjc-int.37signals.com
#
ssh app@fizzy-lb-502.sjc-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      $log_filters \
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-app-501.sjc-int.37signals.com \
      --read-target=fizzy-app-502.sjc-int.37signals.com
