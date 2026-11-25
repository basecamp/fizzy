#!/usr/bin/env bash
# Route the hosted MCP's host name from a destination's load balancers to the
# servers that run it.
#
#   saas/script/configure-lb-mcp.sh staging|production|beta1 [--without <host>]
#
# Production and staging route to basecamp/fizzy-mcp-server's own Kamal app, on
# its fizzy-mcp hosts (that repo's docs/operations/dedicated-deploy.md). beta1
# routes to the fizzy_mcp accessory on its web host (saas/config/deploy.yml).
#
# --without routes to every target but one, so saas/bin/mcp-rolling-reboot can
# drain a host before rebooting its accessory, then rerun this without it to
# put the host back. It refuses to leave a destination with no target.
#
# A separate kamal-proxy service, fizzy_mcp, beside the app's `fizzy` service,
# so this never redeploys the app's route. No read targets: the exchange's token
# is written on the iad primary and read straight back. The dedicated hosts call
# Fizzy through iad's load balancers for the same reason.
#
# --client-ip-header=True-Client-IP --forward-headers make the client the first
# X-Forwarded-For entry. Cloudflare sets True-Client-IP and the F5s pass TLS
# through untouched (saas/lib/fizzy/saas/true_client_ip.rb), so without them the
# first entry would be Cloudflare's edge and every user would share one
# exchange budget (FIZZY_MCP_TRUST_PROXY keys on the first entry,
# fizzy-mcp-server#16). The target's kamal-proxy keeps the chain
# (forward_headers: true) and appends the balancer.
#
# --health-check-host sends each target's /up health check with the MCP host
# name, so it reaches the MCP server's own /up through the target's kamal-proxy,
# which routes by host. Without it a dedicated host has nothing to answer the
# check, and an accessory host answers with the app's /up, which can't see the
# MCP container.
#
# --target-timeout=60s matches the server's response_timeout: a request runs
# up to 45s, past kamal-proxy's 30s default.
#
# TLS: kamal-proxy gets the certificate by ACME, as it does for the app, once
# DNS for the name reaches these balancers.
set -euo pipefail

usage="usage: saas/script/configure-lb-mcp.sh staging|production|beta1 [--without <host>]"
destination=${1:?$usage}
shift
accessory=false
without=""
while (( $# > 0 )); do
  case "$1" in
    --without) without=${2:?--without needs a host}; shift 2 ;;
    *) echo "unknown argument: $1" >&2; echo "$usage" >&2; exit 1 ;;
  esac
done

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
    targets=(
      fizzy-mcp-101.df-iad-int.37signals.com fizzy-mcp-102.df-iad-int.37signals.com
      fizzy-mcp-01.sc-chi-int.37signals.com fizzy-mcp-02.sc-chi-int.37signals.com
    )
    ;;
  staging)
    host=mcp.fizzy-staging.com
    acme=(--tls-acme-cache-path=/certificates)
    balancers=(
      fizzy-staging-lb-01.sc-chi-int.37signals.com fizzy-staging-lb-101.df-iad-int.37signals.com
      fizzy-staging-lb-401.df-ams-int.37signals.com fizzy-staging-lb-501.sjc-int.37signals.com
    )
    targets=(fizzy-staging-mcp-101.df-iad-int.37signals.com fizzy-staging-mcp-01.sc-chi-int.37signals.com)
    ;;
  beta1)
    host=beta1-mcp.fizzy-beta.com
    acme=()
    balancers=(fizzy-beta-lb-101.df-iad-int.37signals.com)
    targets=(fizzy-beta-app-101.df-iad-int.37signals.com)
    accessory=true
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
  echo "==> $balancer: $host -> ${target_flags[*]#--target=}$($accessory && echo " (accessory)")"
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
        --health-check-host="$host" \
        "${target_flags[@]}"
done
