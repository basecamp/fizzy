#!/usr/bin/env bash

set -e

# Beta 1: fizzy-beta-lb-101 -> fizzy-beta-app-101
ssh app@fizzy-beta-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --force \
      --tls \
      --host=beta1.fizzy-beta.com \
      --target=fizzy-beta-app-101.df-iad-int.37signals.com
