#!/usr/bin/env bash

set -e

# fizzy-staging-lb-01.sc-chi-int.37signals.com
#
#   Service      Host                         Path    Target                                                                                       State    TLS
#   fizzy        fizzy.37signals-staging.com  /       fizzy-staging-app-01.sc-chi-int.37signals.com,fizzy-staging-app-02.sc-chi-int.37signals.com  running  yes
#   fizzy-admin  fizzy.37signals-staging.com  /admin  fizzy-staging-app-01.sc-chi-int.37signals.com                                                running  yes
ssh app@fizzy-staging-lb-01.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --tls \
      --host=fizzy.37signals-staging.com \
      --target=fizzy-staging-app-01.sc-chi-int.37signals.com \
      --target=fizzy-staging-app-101.df-iad-int.37signals.com \
      --target=fizzy-staging-app-401.df-ams-int.37signals.com \
      --read-target=fizzy-staging-app-02.sc-chi-int.37signals.com \
      --default-writer=fizzy-staging-app-01.sc-chi-int.37signals.com \
      --dynamic-load-balancing \
      --tls-acme-cache-path=/certificates

ssh app@fizzy-staging-lb-01.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy-admin \
      --host=fizzy.37signals-staging.com \
      --path-prefix /admin \
      --strip-path-prefix=false \
      --target=fizzy-staging-app-01.sc-chi-int.37signals.com

# fizzy-staging-lb-101.df-iad-int.37signals.com
#
#   Service      Host                         Path    Target                                                                                        State    TLS
#   fizzy        fizzy.37signals-staging.com  /       fizzy-staging-app-01.sc-chi-int.37signals.com,fizzy-staging-app-102.df-iad-int.37signals.com  running  yes
#   fizzy-admin  fizzy.37signals-staging.com  /admin  fizzy-staging-app-01.sc-chi-int.37signals.com                                                 running  yes
ssh app@fizzy-staging-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --tls \
      --host=fizzy.37signals-staging.com \
      --target=fizzy-staging-app-01.sc-chi-int.37signals.com \
      --target=fizzy-staging-app-101.df-iad-int.37signals.com \
      --target=fizzy-staging-app-401.df-ams-int.37signals.com \
      --read-target=fizzy-staging-app-102.df-iad-int.37signals.com \
      --default-writer=fizzy-staging-app-01.sc-chi-int.37signals.com \
      --dynamic-load-balancing \
      --tls-acme-cache-path=/certificates

ssh app@fizzy-staging-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy-admin \
      --host=fizzy.37signals-staging.com \
      --path-prefix /admin \
      --strip-path-prefix=false \
      --target=fizzy-staging-app-01.sc-chi-int.37signals.com

# fizzy-staging-lb-401.df-ams-int.37signals.com
#
#   Service      Host                         Path    Target                                                                                        State    TLS
#   fizzy        fizzy.37signals-staging.com  /       fizzy-staging-app-01.sc-chi-int.37signals.com,fizzy-staging-app-402.df-ams-int.37signals.com  running  yes
#   fizzy-admin  fizzy.37signals-staging.com  /admin  fizzy-staging-app-01.sc-chi-int.37signals.com                                                 running  yes
ssh app@fizzy-staging-lb-401.df-ams-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy \
      --tls \
      --host=fizzy.37signals-staging.com \
      --target=fizzy-staging-app-01.sc-chi-int.37signals.com \
      --target=fizzy-staging-app-101.df-iad-int.37signals.com \
      --target=fizzy-staging-app-401.df-ams-int.37signals.com \
      --read-target=fizzy-staging-app-402.df-ams-int.37signals.com \
      --default-writer=fizzy-staging-app-01.sc-chi-int.37signals.com \
      --dynamic-load-balancing \
      --tls-acme-cache-path=/certificates

ssh app@fizzy-staging-lb-401.df-ams-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy fizzy-admin \
      --host=fizzy.37signals-staging.com \
      --path-prefix /admin \
      --strip-path-prefix=false \
      --target=fizzy-staging-app-01.sc-chi-int.37signals.com
