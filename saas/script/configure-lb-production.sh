#!/usr/bin/env bash

set -e

# fizzy-lb-101.df-iad-int.37signals.com
#
ssh app@fizzy-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
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
      --force \
      --tls \
      --host=app.fizzy.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --target=fizzy-app-102.df-iad-int.37signals.com \
      --read-target=fizzy-app-401.df-ams-int.37signals.com \
      --read-target=fizzy-app-402.df-ams-int.37signals.com
