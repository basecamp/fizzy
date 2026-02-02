#!/usr/bin/env bash

set -e

# fizzy-staging-lb-01.sc-chi-int.37signals.com
#
ssh app@fizzy-staging-lb-01.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
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
      --force \
      --tls \
      --host=app.fizzy-staging.com \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-staging-app-101.df-iad-int.37signals.com \
      --target=fizzy-staging-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-staging-app-401.df-ams-int.37signals.com \
      --read-target=fizzy-staging-app-402.df-ams-int.37signals.com 

