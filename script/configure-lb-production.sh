#!/usr/bin/env bash

set -e

# fizzy-lb-101.df-iad-int.37signals.com
#
#   Service       Host                                             Path    Target                                                                         State    TLS
#   boxcar        fizzy.37signals.com,box-car.com,app.box-car.com  /       fizzy-app-101.df-iad-int.37signals.com,fizzy-app-102.df-iad-int.37signals.com  running  yes
#   boxcar-admin  fizzy.37signals.com,box-car.com,app.box-car.com  /admin  fizzy-app-101.df-iad-int.37signals.com                                         running  yes
ssh app@fizzy-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy boxcar \
      --tls \
      --host=fizzy.37signals.com,box-car.com,app.box-car.com \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --read-target=fizzy-app-102.df-iad-int.37signals.com \
      --tls-acme-cache-path=/certificates

ssh app@fizzy-lb-101.df-iad-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy boxcar-admin \
    --host=fizzy.37signals.com,box-car.com,app.box-car.com \
      --path-prefix /admin \
      --strip-path-prefix=false \
      --target=fizzy-app-101.df-iad-int.37signals.com


# fizzy-lb-01.sc-chi-int.37signals.com
#
#   Service       Host                                             Path    Target                                                                        State    TLS
#   boxcar        fizzy.37signals.com,box-car.com,app.box-car.com  /       fizzy-app-101.df-iad-int.37signals.com,fizzy-app-02.sc-chi-int.37signals.com  running  yes
#   boxcar-admin  fizzy.37signals.com,box-car.com,app.box-car.com  /admin  fizzy-app-101.df-iad-int.37signals.com                                        running  yes
ssh app@fizzy-lb-01.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy boxcar \
      --tls \
      --host=fizzy.37signals.com,box-car.com,app.box-car.com \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --read-target=fizzy-app-02.sc-chi-int.37signals.com \
      --tls-acme-cache-path=/certificates

ssh app@fizzy-lb-01.sc-chi-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy boxcar-admin \
      --host=fizzy.37signals.com,box-car.com,app.box-car.com \
      --path-prefix /admin \
      --strip-path-prefix=false \
      --target=fizzy-app-101.df-iad-int.37signals.com


# fizzy-lb-401.df-ams-int.37signals.com
#
#   Service       Host                                             Path    Target                                                                         State    TLS
#   boxcar        fizzy.37signals.com,box-car.com,app.box-car.com  /       fizzy-app-101.df-iad-int.37signals.com,fizzy-app-402.df-ams-int.37signals.com  running  yes
#   boxcar-admin  fizzy.37signals.com,box-car.com,app.box-car.com  /admin  fizzy-app-101.df-iad-int.37signals.com                                         running  yes
ssh app@fizzy-lb-401.df-ams-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy boxcar \
      --tls \
      --host=fizzy.37signals.com,box-car.com,app.box-car.com \
      --target=fizzy-app-101.df-iad-int.37signals.com \
      --read-target=fizzy-app-402.df-ams-int.37signals.com \
      --tls-acme-cache-path=/certificates

ssh app@fizzy-lb-401.df-ams-int.37signals.com \
  docker exec fizzy-load-balancer \
    kamal-proxy deploy boxcar-admin \
      --host=fizzy.37signals.com,box-car.com,app.box-car.com \
      --path-prefix /admin \
      --strip-path-prefix=false \
      --target=fizzy-app-101.df-iad-int.37signals.com
