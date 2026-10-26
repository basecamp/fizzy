#!/usr/bin/env bash
# Route the hosted MCP's host name from a destination's load balancers to the
# fizzy_mcp accessory, on the iad web hosts that run it (saas/config/deploy.yml).
#
#   saas/script/configure-lb-mcp.sh staging|production|beta1 [--without <host>]
#
# --without routes to every target but one, so saas/bin/mcp-rolling-reboot can
# drain a host before rebooting its accessory, then rerun this without it to
# put the host back. It refuses to leave a destination with no target.
#
# A separate kamal-proxy service, fizzy_mcp, beside the app's `fizzy` service,
# so this never redeploys the app's route. Every load balancer sends MCP to iad
# alone, with no read targets: the exchange's token is written on the iad
# primary and read straight back.
#
# --client-ip-header=True-Client-IP --forward-headers make the client the first
# X-Forwarded-For entry. Cloudflare sets True-Client-IP and the F5s pass TLS
# through untouched (saas/lib/fizzy/saas/true_client_ip.rb), so without them the
# first entry would be Cloudflare's edge and every user would share one
# exchange budget (FIZZY_MCP_TRUST_PROXY keys on the first entry,
# fizzy-mcp-server#16). The web host's kamal-proxy keeps the chain
# (forward_headers: true on the accessory) and appends the balancer.
#
# --target-timeout=60s matches the accessory's response_timeout: a request runs
# up to 45s, past kamal-proxy's 30s default.
#
# TLS: kamal-proxy gets the certificate by ACME, as it does for the app, once
# DNS for the name reaches these balancers.
set -euo pipefail

destination=${1:?usage: saas/script/configure-lb-mcp.sh staging|production|beta1 [--without <host>]}
without=""
if [[ ${2:-} == --without ]]; then
  without=${3:?--without needs a host}
elif [[ -n ${2:-} ]]; then
  echo "unknown argument: $2" >&2
  exit 1
fi

case "$destination" in
  production)
    host=mcp.fizzy.do
    acme=(--tls-acme-cache-path=/certificates)
    balancers=(
      fizzy-lb-101.df-iad-int.37signals.com fizzy-lb-102.df-iad-int.37signals.com
      fizzy-lb-01.sc-chi-int.37signals.com fizzy-lb-02.sc-chi-int.37signals.com
      fizzy-lb-401.df-ams-int.37signals.com fizzy-lb-402.df-ams-int.37signals.com
      fizzy-lb-501.sjc-int.37signals.com fizzy-lb-502.sjc-int.37signals.com
    )
    targets=(fizzy-app-101.df-iad-int.37signals.com fizzy-app-102.df-iad-int.37signals.com)
    ;;
  staging)
    host=mcp.fizzy-staging.com
    acme=(--tls-acme-cache-path=/certificates)
    balancers=(
      fizzy-staging-lb-01.sc-chi-int.37signals.com fizzy-staging-lb-101.df-iad-int.37signals.com
      fizzy-staging-lb-401.df-ams-int.37signals.com fizzy-staging-lb-501.sjc-int.37signals.com
    )
    targets=(fizzy-staging-app-101.df-iad-int.37signals.com fizzy-staging-app-102.df-iad-int.37signals.com)
    ;;
  beta1)
    host=beta1-mcp.fizzy-beta.com
    acme=()
    balancers=(fizzy-beta-lb-101.df-iad-int.37signals.com)
    targets=(fizzy-beta-app-101.df-iad-int.37signals.com)
    ;;
  *)
    echo "unknown destination: $destination" >&2
    exit 1
    ;;
esac

target_flags=()
for target in "${targets[@]}"; do
  [[ $target == "$without" ]] || target_flags+=("--target=$target")
done
if [[ -n $without && ${#target_flags[@]} -eq ${#targets[@]} ]]; then
  echo "$without is not a $destination target" >&2
  exit 1
fi
(( ${#target_flags[@]} > 0 )) || { echo "refusing to leave $host with no target" >&2; exit 1; }

for balancer in "${balancers[@]}"; do
  echo "==> $balancer: $host -> ${target_flags[*]#--target=}"
  # Refuse rather than route MCP without the client's address on a balancer
  # still running a kamal-proxy older than v0.10.0 (the old :lb build), i.e.
  # one not yet rebooted onto the pin in saas/config/deploy.*.yml.
  help=$(ssh "app@$balancer" docker exec fizzy-load-balancer kamal-proxy deploy --help)
  if [[ $help != *--client-ip-header* ]]; then
    echo "$balancer: this kamal-proxy has no --client-ip-header; not routing $host" >&2
    exit 1
  fi
  ssh "app@$balancer" \
    docker exec fizzy-load-balancer \
      kamal-proxy deploy fizzy_mcp \
        --force \
        --tls \
        --host="$host" \
        ${acme[@]+"${acme[@]}"} \
        --client-ip-header=True-Client-IP \
        --forward-headers \
        --target-timeout=60s \
        "${target_flags[@]}"
done
