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

# Beta 2: fizzy-beta-lb-102 -> fizzy-beta-app-102
ssh app@fizzy-beta-lb-102.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --force \
      --tls \
      --host=beta2.fizzy-beta.com \
      --target=fizzy-beta-app-102.df-iad-int.37signals.com

# Beta 3: fizzy-beta-lb-103 -> fizzy-beta-app-103
ssh app@fizzy-beta-lb-103.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --force \
      --tls \
      --host=beta3.fizzy-beta.com \
      --target=fizzy-beta-app-103.df-iad-int.37signals.com

# Beta 4: fizzy-beta-lb-104 -> fizzy-beta-app-104
ssh app@fizzy-beta-lb-104.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --force \
      --tls \
      --host=beta4.fizzy-beta.com \
      --target=fizzy-beta-app-104.df-iad-int.37signals.com
