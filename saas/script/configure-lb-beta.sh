#!/usr/bin/env bash

set -e

# fizzy-beta-lb-01.sc-chi-int.37signals.com
#
ssh app@fizzy-beta-lb-01.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --force \
      --tls \
      --host=fizzy-beta.37signals.com \
      --writer-affinity-timeout=0 \
      --target=fizzy-beta-app-101.df-iad-int.37signals.com \
      --read-target=fizzy-beta-app-01.sc-chi-int.37signals.com
