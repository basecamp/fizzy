#!/usr/bin/env bash
# api.sh - HTTP helpers for Fizzy API
# Handles authentication, rate limiting, caching, retries


# Configuration

FIZZY_USER_AGENT="fizzy/$FIZZY_VERSION (https://github.com/basecamp/fizzy)"
FIZZY_MAX_RETRIES="${FIZZY_MAX_RETRIES:-5}"
FIZZY_BASE_DELAY="${FIZZY_BASE_DELAY:-1}"


# ETag Cache Helpers

_cache_dir() {
  local configured
  configured=$(get_config "cache_dir" "")
  if [[ -n "$configured" ]]; then
    echo "$configured"
  else
    echo "${XDG_CACHE_HOME:-$HOME/.cache}/fizzy"
  fi
}

_cache_key() {
  local account_slug="$1" url="$2" token="$3"
  local token_hash=""
  if [[ -n "$token" ]]; then
    if command -v shasum &>/dev/null; then
      token_hash=$(echo -n "$token" | shasum -a 256 | cut -c1-16)
    else
      token_hash=$(echo -n "$token" | sha256sum | cut -c1-16)
    fi
  fi
  local cache_input="${FIZZY_BASE_URL:-}:${account_slug}:${token_hash}:${url}"
  if command -v shasum &>/dev/null; then
    echo -n "$cache_input" | shasum -a 256 | cut -d' ' -f1
  else
    echo -n "$cache_input" | sha256sum | cut -d' ' -f1
  fi
}

_cache_get_etag() {
  local key="$1"
  local etags_file="$(_cache_dir)/etags.json"
  if [[ -f "$etags_file" ]]; then
    jq -r --arg k "$key" '.[$k] // empty' "$etags_file" 2>/dev/null || true
  fi
}

_cache_get_body() {
  local key="$1"
  local body_file="$(_cache_dir)/responses/${key}.body"
  if [[ -f "$body_file" ]]; then
    cat "$body_file"
  fi
}

_cache_set() {
  local key="$1" body="$2" etag="$3" headers="$4"
  local cache_dir="$(_cache_dir)"
  local etags_file="$cache_dir/etags.json"
  local body_file="$cache_dir/responses/${key}.body"
  local headers_file="$cache_dir/responses/${key}.headers"

  mkdir -p "$cache_dir/responses"

  echo "$body" > "${body_file}.tmp" && mv "${body_file}.tmp" "$body_file"

  if [[ -n "$headers" ]]; then
    echo "$headers" > "${headers_file}.tmp" && mv "${headers_file}.tmp" "$headers_file"
  fi

  if [[ -f "$etags_file" ]]; then
    jq --arg k "$key" --arg v "$etag" '.[$k] = $v' "$etags_file" > "${etags_file}.tmp" \
      && mv "${etags_file}.tmp" "$etags_file"
  else
    jq -n --arg k "$key" --arg v "$etag" '{($k): $v}' > "$etags_file"
  fi
}


# Authentication

ensure_auth() {
  local token
  token=$(get_access_token) || {
    die "Not authenticated. Run: fizzy auth login" $EXIT_AUTH
  }

  if is_token_expired && [[ -z "${FIZZY_ACCESS_TOKEN:-}" ]]; then
    debug "Token expired, refreshing..."
    if ! refresh_token; then
      die "Token expired and refresh failed. Run: fizzy auth login" $EXIT_AUTH
    fi
    token=$(get_access_token)
  fi

  echo "$token"
}

ensure_account_slug() {
  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "No account configured. Run: fizzy config set account_slug <id>" $EXIT_USAGE \
      "Or set FIZZY_ACCOUNT_SLUG environment variable"
  fi
  echo "$account_slug"
}


# HTTP Request Helpers

api_get() {
  local path="$1"
  shift

  local token account_slug
  token=$(ensure_auth) || exit $?
  account_slug=$(ensure_account_slug) || exit $?

  # Strip leading slash from path and add it explicitly to avoid double slashes
  path="${path#/}"
  local url="$FIZZY_BASE_URL/$account_slug/$path"
  _api_request GET "$url" "$token" "" "$@"
}

api_post() {
  local path="$1"
  local body="${2:-}"
  shift 2 || shift

  local token account_slug
  token=$(ensure_auth) || exit $?
  account_slug=$(ensure_account_slug) || exit $?

  # Strip leading slash from path and add it explicitly to avoid double slashes
  path="${path#/}"
  local url="$FIZZY_BASE_URL/$account_slug/$path"
  _api_request POST "$url" "$token" "$body" "$@"
}

api_put() {
  local path="$1"
  local body="${2:-}"
  shift 2 || shift

  local token account_slug
  token=$(ensure_auth) || exit $?
  account_slug=$(ensure_account_slug) || exit $?

  # Strip leading slash from path and add it explicitly to avoid double slashes
  path="${path#/}"
  local url="$FIZZY_BASE_URL/$account_slug/$path"
  _api_request PUT "$url" "$token" "$body" "$@"
}

api_patch() {
  local path="$1"
  local body="${2:-}"
  shift 2 || shift

  local token account_slug
  token=$(ensure_auth) || exit $?
  account_slug=$(ensure_account_slug) || exit $?

  # Strip leading slash from path and add it explicitly to avoid double slashes
  path="${path#/}"
  local url="$FIZZY_BASE_URL/$account_slug/$path"
  _api_request PATCH "$url" "$token" "$body" "$@"
}

api_delete() {
  local path="$1"
  shift

  local token account_slug
  token=$(ensure_auth) || exit $?
  account_slug=$(ensure_account_slug) || exit $?

  # Strip leading slash from path and add it explicitly to avoid double slashes
  path="${path#/}"
  local url="$FIZZY_BASE_URL/$account_slug/$path"
  _api_request DELETE "$url" "$token" "" "$@"
}

# Unauthenticated request (for OAuth discovery)
api_get_unauth() {
  local url="$1"
  shift

  _api_request GET "$url" "" "" "$@"
}

api_post_unauth() {
  local url="$1"
  local body="${2:-}"
  shift 2 || shift

  _api_request POST "$url" "" "$body" "$@"
}

_api_request() {
  local method="$1"
  local url="$2"
  local token="$3"
  local body="${4:-}"
  shift 4 || shift 3 || shift 2 || shift

  local attempt=1
  local delay=$FIZZY_BASE_DELAY
  local response http_code headers_file

  headers_file=$(mktemp)
  trap "rm -f '$headers_file'" RETURN

  # ETag cache setup (GET requests only)
  local cache_key="" cached_etag=""
  if [[ "$method" == "GET" ]] && [[ "${FIZZY_CACHE_ENABLED:-true}" == "true" ]] && [[ -n "$token" ]]; then
    local account_slug
    account_slug=$(get_account_slug 2>/dev/null || echo "")
    if [[ -n "$account_slug" ]]; then
      cache_key=$(_cache_key "$account_slug" "$url" "$token")
      cached_etag=$(_cache_get_etag "$cache_key")
    fi
  fi

  while (( attempt <= FIZZY_MAX_RETRIES )); do
    debug "API $method $url (attempt $attempt)"

    local curl_args=(
      -s
      -X "$method"
      -H "User-Agent: $FIZZY_USER_AGENT"
      -H "Content-Type: application/json"
      -H "Accept: application/json"
      -D "$headers_file"
      -w '\n%{http_code}'
    )

    # Add Authorization header if token provided
    if [[ -n "$token" ]]; then
      curl_args+=(-H "Authorization: Bearer $token")
    fi

    # Add If-None-Match header for cached responses
    if [[ -n "$cached_etag" ]]; then
      curl_args+=(-H "If-None-Match: $cached_etag")
      debug "Cache: If-None-Match $cached_etag"
    fi

    if [[ -n "$body" ]]; then
      curl_args+=(-d "$body")
    fi

    curl_args+=("$@")
    curl_args+=("$url")

    # Log curl command in verbose mode (with redacted token)
    if [[ "$FIZZY_VERBOSE" == "true" ]]; then
      local curl_cmd="curl"
      local prev_was_H=false
      for arg in "${curl_args[@]}"; do
        if [[ "$arg" == "-H" ]]; then
          prev_was_H=true
          continue
        elif $prev_was_H; then
          prev_was_H=false
          if [[ "$arg" == "Authorization: Bearer"* ]]; then
            curl_cmd+=" -H 'Authorization: Bearer [REDACTED]'"
          else
            curl_cmd+=" -H '$arg'"
          fi
        elif [[ "$arg" == *" "* ]]; then
          curl_cmd+=" '$arg'"
        else
          curl_cmd+=" $arg"
        fi
      done
      echo "[curl] $curl_cmd" >&2
    fi

    local output curl_exit
    output=$(curl "${curl_args[@]}") || curl_exit=$?

    if [[ -n "${curl_exit:-}" ]]; then
      case "$curl_exit" in
        6)  die "Could not resolve host" $EXIT_NETWORK ;;
        7)  die "Connection refused" $EXIT_NETWORK ;;
        28) die "Connection timed out" $EXIT_NETWORK ;;
        35) die "SSL/TLS handshake failed" $EXIT_NETWORK ;;
        *)  die "Network error (curl exit $curl_exit)" $EXIT_NETWORK ;;
      esac
    fi

    http_code=$(echo "$output" | tail -n1)
    response=$(echo "$output" | sed '$d')

    debug "HTTP $http_code"

    case "$http_code" in
      304)
        # Not Modified - return cached response
        if [[ -n "$cache_key" ]]; then
          debug "Cache hit: 304 Not Modified"
          _cache_get_body "$cache_key"
          return 0
        fi
        die "304 received but no cached response available" $EXIT_API
        ;;
      200|201|204)
        # Cache successful GET responses with ETag
        if [[ "$method" == "GET" ]] && [[ -n "$cache_key" ]]; then
          local etag
          etag=$(grep -i '^ETag:' "$headers_file" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r\n')
          if [[ -n "$etag" ]]; then
            local cached_headers
            cached_headers=$(cat "$headers_file")
            _cache_set "$cache_key" "$response" "$etag" "$cached_headers"
            debug "Cache: stored with ETag $etag"
          fi
        fi

        # Follow Location header on 201 with empty body (RESTful create pattern)
        if [[ "$http_code" == "201" ]] && [[ -z "$response" ]]; then
          local location
          location=$(grep -i '^location:' "$headers_file" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r\n' || true)
          if [[ -n "$location" ]]; then
            # Convert relative URL to absolute
            if [[ "$location" != http* ]]; then
              location="$FIZZY_BASE_URL$location"
            fi
            # Strip .json suffix if present (API returns /cards/1.json but endpoint is /cards/1)
            location="${location%.json}"
            debug "Following Location header: $location"
            response=$(curl -s -H "Authorization: Bearer $token" -H "Accept: application/json" "$location")
          fi
        fi

        echo "$response"
        return 0
        ;;
      429)
        local retry_after
        retry_after=$(grep -i "Retry-After:" "$headers_file" | awk '{print $2}' | tr -d '\r')
        delay=${retry_after:-$((FIZZY_BASE_DELAY * 2 ** (attempt - 1)))}
        info "Rate limited, waiting ${delay}s..."
        sleep "$delay"
        ((attempt++))
        ;;
      401)
        if [[ $attempt -eq 1 ]] && [[ -z "${FIZZY_ACCESS_TOKEN:-}" ]] && [[ -n "$token" ]]; then
          debug "401 received, attempting token refresh"
          if refresh_token; then
            token=$(get_access_token)
            ((attempt++))
            continue
          fi
        fi
        die "Authentication failed" $EXIT_AUTH "Run: fizzy auth login"
        ;;
      403)
        if [[ "$method" =~ ^(POST|PUT|PATCH|DELETE)$ ]]; then
          local current_scope
          current_scope=$(get_token_scope 2>/dev/null || echo "unknown")
          if [[ "$current_scope" == "read" ]]; then
            die "Permission denied: read-only token cannot perform write operations" $EXIT_FORBIDDEN \
              "Re-authenticate with write scope: fizzy auth login --scope write"
          fi
        fi
        die "Permission denied" $EXIT_FORBIDDEN \
          "You don't have access to this resource"
        ;;
      404)
        die "Not found" $EXIT_NOT_FOUND
        ;;
      422)
        # Unprocessable Entity - validation error
        local error_msg
        error_msg=$(echo "$response" | jq -r '.errors | to_entries | map("\(.key): \(.value | join(", "))") | join("; ")' 2>/dev/null || echo "Validation failed")
        die "Validation error: $error_msg" $EXIT_USAGE
        ;;
      500)
        die "Server error (500)" $EXIT_API \
          "The server encountered an internal error"
        ;;
      502|503|504)
        delay=$((FIZZY_BASE_DELAY * 2 ** (attempt - 1)))
        info "Gateway error ($http_code), retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
        ;;
      *)
        local error_msg
        error_msg=$(echo "$response" | jq -r '.error // .message // "Unknown error"' 2>/dev/null || echo "Request failed")
        die "$error_msg (HTTP $http_code)" $EXIT_API
        ;;
    esac
  done

  die "Request failed after $FIZZY_MAX_RETRIES retries" $EXIT_API
}


# Token Refresh

refresh_token() {
  local creds
  creds=$(load_credentials)

  local refresh_tok
  refresh_tok=$(echo "$creds" | jq -r '.refresh_token // empty')

  if [[ -z "$refresh_tok" ]]; then
    debug "No refresh token available"
    return 1
  fi

  local client_id client_secret
  client_id=$(get_client_id)
  client_secret=$(get_client_secret)

  if [[ -z "$client_id" ]]; then
    debug "No client credentials found"
    return 1
  fi

  # Preserve original scope for new credentials
  local original_scope
  original_scope=$(echo "$creds" | jq -r '.scope // empty')

  debug "Refreshing token..."

  # Use discovered token endpoint instead of hardcoded path
  local token_endpoint
  token_endpoint=$(_token_endpoint)

  if [[ -z "$token_endpoint" ]]; then
    debug "Could not discover token endpoint"
    return 1
  fi

  # Build curl command with --data-urlencode for proper URL encoding
  # Include client_secret only if present (for confidential clients)
  local response curl_exit
  if [[ -n "$client_secret" ]]; then
    response=$(curl -s -X POST \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=refresh_token" \
      --data-urlencode "refresh_token=$refresh_tok" \
      --data-urlencode "client_id=$client_id" \
      --data-urlencode "client_secret=$client_secret" \
      "$token_endpoint") || curl_exit=$?
  else
    response=$(curl -s -X POST \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=refresh_token" \
      --data-urlencode "refresh_token=$refresh_tok" \
      --data-urlencode "client_id=$client_id" \
      "$token_endpoint") || curl_exit=$?
  fi

  if [[ -n "${curl_exit:-}" ]]; then
    debug "Token refresh network error (curl exit $curl_exit)"
    return 1
  fi

  local new_access_token new_refresh_token expires_in new_scope
  new_access_token=$(echo "$response" | jq -r '.access_token // empty')
  new_refresh_token=$(echo "$response" | jq -r '.refresh_token // empty')
  expires_in=$(echo "$response" | jq -r '.expires_in // empty')
  new_scope=$(echo "$response" | jq -r '.scope // empty')

  if [[ -z "$new_access_token" ]]; then
    debug "Token refresh failed: $response"
    return 1
  fi

  # Use scope from response if provided, otherwise preserve original scope
  local final_scope="${new_scope:-$original_scope}"

  # Build credentials - only include expires_at if server provided expires_in
  local new_creds
  if [[ -n "$expires_in" ]]; then
    local expires_at
    expires_at=$(($(date +%s) + expires_in))
    new_creds=$(jq -n \
      --arg access_token "$new_access_token" \
      --arg refresh_token "${new_refresh_token:-$refresh_tok}" \
      --argjson expires_at "$expires_at" \
      --arg scope "$final_scope" \
      '{access_token: $access_token, refresh_token: $refresh_token, expires_at: $expires_at, scope: $scope}')
  else
    # No expiration - token is long-lived
    new_creds=$(jq -n \
      --arg access_token "$new_access_token" \
      --arg refresh_token "${new_refresh_token:-$refresh_tok}" \
      --arg scope "$final_scope" \
      '{access_token: $access_token, refresh_token: $refresh_token, expires_at: null, scope: $scope}')
  fi

  save_credentials "$new_creds"
  debug "Token refreshed successfully"
  return 0
}


# Pagination

api_get_all() {
  local path="$1"
  local max_pages="${2:-100}"

  local token account_slug
  token=$(ensure_auth) || exit $?
  account_slug=$(ensure_account_slug) || exit $?

  # Strip leading slash from path and add it explicitly to avoid double slashes
  path="${path#/}"

  local all_results="[]"
  local page=1
  local url="$FIZZY_BASE_URL/$account_slug/$path"

  local headers_file
  headers_file=$(mktemp)
  trap "rm -f '$headers_file'" RETURN

  while (( page <= max_pages )); do
    debug "Fetching page $page: $url"

    local output http_code response curl_exit
    output=$(curl -s \
      -H "Authorization: Bearer $token" \
      -H "User-Agent: $FIZZY_USER_AGENT" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -D "$headers_file" \
      -w '\n%{http_code}' \
      "$url") || curl_exit=$?

    if [[ -n "${curl_exit:-}" ]]; then
      case "$curl_exit" in
        6)  die "Could not resolve host" $EXIT_NETWORK ;;
        7)  die "Connection refused" $EXIT_NETWORK ;;
        28) die "Connection timed out" $EXIT_NETWORK ;;
        *)  die "Network error (curl exit $curl_exit)" $EXIT_NETWORK ;;
      esac
    fi

    http_code=$(echo "$output" | tail -n1)
    response=$(echo "$output" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
      die "API request failed (HTTP $http_code)" $EXIT_API
    fi

    if [[ "$all_results" == "[]" ]]; then
      all_results="$response"
    else
      all_results=$(echo "$all_results" "$response" | jq -s '.[0] + .[1]')
    fi

    # Parse Link header for next page (RFC 5988)
    local next_url
    next_url=$(grep -i '^Link:' "$headers_file" | sed -n 's/.*<\([^>]*\)>; rel="next".*/\1/p' | tr -d '\r')

    if [[ -z "$next_url" ]]; then
      break
    fi

    url="$next_url"
    ((page++))
  done

  echo "$all_results"
}


# URL helpers

board_path() {
  local resource="$1"
  local board_id="${2:-$(get_board_id)}"

  if [[ -z "$board_id" ]]; then
    die "No board specified. Use --board or set in .fizzy/config.json" $EXIT_USAGE
  fi

  echo "/boards/$board_id$resource"
}

card_path() {
  local card_number="$1"
  local resource="${2:-}"

  echo "/cards/$card_number$resource"
}
