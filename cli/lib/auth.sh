#!/usr/bin/env bash
# auth.sh - OAuth 2.1 authentication with Dynamic Client Registration
# Uses .well-known/oauth-authorization-server discovery (RFC 8414)


# OAuth Configuration

FIZZY_REDIRECT_PORT="${FIZZY_REDIRECT_PORT:-8976}"
FIZZY_REDIRECT_URI="http://127.0.0.1:$FIZZY_REDIRECT_PORT/callback"

FIZZY_CLIENT_NAME="fizzy-cli"
FIZZY_CLIENT_URI="https://github.com/basecamp/fizzy"

# Cached OAuth server metadata (populated by _ensure_oauth_config)
declare -g _FIZZY_OAUTH_CONFIG=""


# OAuth Discovery (RFC 8414)

_discover_oauth_config() {
  # Fetch OAuth 2.1 server metadata from .well-known endpoint
  local discovery_url="$FIZZY_BASE_URL/.well-known/oauth-authorization-server"

  debug "Discovering OAuth config from: $discovery_url"

  local response
  response=$(curl -s -f "$discovery_url") || {
    die "Failed to discover OAuth configuration from $discovery_url" $EXIT_AUTH \
      "Ensure FIZZY_BASE_URL points to a valid Fizzy instance"
  }

  # Validate required fields
  local authorization_endpoint token_endpoint
  authorization_endpoint=$(echo "$response" | jq -r '.authorization_endpoint // empty')
  token_endpoint=$(echo "$response" | jq -r '.token_endpoint // empty')

  if [[ -z "$authorization_endpoint" ]] || [[ -z "$token_endpoint" ]]; then
    debug "Discovery response: $response"
    die "Invalid OAuth discovery response - missing required endpoints" $EXIT_AUTH
  fi

  _FIZZY_OAUTH_CONFIG="$response"
  debug "OAuth config discovered successfully"
}

_ensure_oauth_config() {
  # Lazily fetch and cache OAuth config
  if [[ -z "$_FIZZY_OAUTH_CONFIG" ]]; then
    _discover_oauth_config
  fi
}

_get_oauth_endpoint() {
  local key="$1"
  _ensure_oauth_config
  echo "$_FIZZY_OAUTH_CONFIG" | jq -r ".$key // empty"
}

# Convenience accessors for OAuth endpoints
_authorization_endpoint() { _get_oauth_endpoint "authorization_endpoint"; }
_token_endpoint() { _get_oauth_endpoint "token_endpoint"; }
_registration_endpoint() { _get_oauth_endpoint "registration_endpoint"; }
_revocation_endpoint() { _get_oauth_endpoint "revocation_endpoint"; }


# Auth Commands

cmd_auth() {
  local action="${1:-status}"
  shift || true

  case "$action" in
    login) _auth_login "$@" ;;
    logout) _auth_logout "$@" ;;
    status) _auth_status "$@" ;;
    refresh) _auth_refresh "$@" ;;
    --help|-h) _help_auth ;;
    *)
      die "Unknown auth action: $action" $EXIT_USAGE "Run: fizzy auth --help"
      ;;
  esac
}


# Login Flow

_auth_login() {
  local no_browser=false
  local scope="write"  # Default to write (read+write) scope

  # Parse login-specific flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-browser)
        no_browser=true
        shift
        ;;
      --scope)
        shift
        case "${1:-}" in
          write|read)
            scope="$1"
            shift
            ;;
          *)
            die "Invalid scope: ${1:-}. Use 'write' or 'read'" $EXIT_USAGE
            ;;
        esac
        ;;
      *)
        shift
        ;;
    esac
  done

  info "Starting authentication..."

  # Check for existing valid token
  if get_access_token &>/dev/null && ! is_token_expired; then
    info "Already authenticated. Use 'fizzy auth logout' first to re-authenticate."
    _auth_status
    return 0
  fi

  # Pre-fetch OAuth config (avoids repeated discovery in subshells)
  _ensure_oauth_config

  # Get or register client
  local client_id client_secret
  if ! _load_client; then
    info "Registering OAuth client..."
    _register_client || die "Failed to register OAuth client" $EXIT_AUTH
  fi
  _load_client

  # Generate PKCE challenge
  local code_verifier code_challenge
  code_verifier=$(_generate_code_verifier)
  code_challenge=$(_generate_code_challenge "$code_verifier")
  debug "Generated code_verifier: $code_verifier"
  debug "Generated code_challenge: $code_challenge"

  # Generate state for CSRF protection
  local state
  state=$(_generate_state)

  # Build authorization URL (using discovered endpoint)
  local auth_endpoint auth_url
  auth_endpoint=$(_authorization_endpoint)
  auth_url="$auth_endpoint?response_type=code"
  auth_url+="&client_id=$client_id"
  auth_url+="&redirect_uri=$(urlencode "$FIZZY_REDIRECT_URI")"
  auth_url+="&code_challenge=$code_challenge"
  auth_url+="&code_challenge_method=S256"
  auth_url+="&scope=$scope"
  auth_url+="&state=$state"

  local auth_code

  if [[ "$no_browser" == "true" ]]; then
    # Headless mode: user manually visits URL and enters code
    echo "Visit this URL to authorize:"
    echo
    echo "  $auth_url"
    echo
    read -rp "Enter the authorization code: " auth_code
    if [[ -z "$auth_code" ]]; then
      die "No authorization code provided" $EXIT_AUTH
    fi
  else
    # Browser mode: open browser and wait for callback
    info "Opening browser for authorization..."
    info "If browser doesn't open, visit: $auth_url"

    # Open browser
    _open_browser "$auth_url"

    # Start local server to receive callback
    auth_code=$(_wait_for_callback "$state") || die "Authorization failed" $EXIT_AUTH
  fi

  # Exchange code for tokens
  info "Exchanging authorization code..."
  _exchange_code "$auth_code" "$code_verifier" "$client_id" "$client_secret" || \
    die "Token exchange failed" $EXIT_AUTH

  # Discover accounts
  info "Discovering accounts..."
  _discover_accounts || warn "Could not discover accounts"

  # Select account if multiple
  _select_account

  info "Authentication successful!"
  _auth_status
}

_auth_logout() {
  if get_access_token &>/dev/null; then
    clear_credentials
    info "Logged out from $FIZZY_BASE_URL"
  else
    info "Not logged in to $FIZZY_BASE_URL"
  fi
}

_auth_status() {
  local format
  format=$(get_format)

  local auth_status="unauthenticated"
  local user_name=""
  local account_slug=""
  local account_name=""
  local expires_at=""
  local token_status="none"
  local scope=""

  if get_access_token &>/dev/null; then
    auth_status="authenticated"

    local creds
    creds=$(load_credentials)
    expires_at=$(echo "$creds" | jq -r '.expires_at // "null"')
    scope=$(echo "$creds" | jq -r '.scope // empty')

    # Determine token status based on expiration
    if [[ "$expires_at" == "null" ]] || [[ "$expires_at" == "0" ]]; then
      token_status="long-lived"
    elif is_token_expired; then
      token_status="expired"
    else
      token_status="valid"
    fi

    local accounts
    accounts=$(load_accounts)
    account_slug=$(get_account_slug)

    if [[ -n "$account_slug" ]] && [[ "$accounts" != "[]" ]]; then
      account_name=$(echo "$accounts" | jq -r --arg slug "$account_slug" \
        '.[] | select(.slug == ("/"+$slug)) | .name // empty')
    fi
  fi

  if [[ "$format" == "json" ]]; then
    jq -n \
      --arg status "$auth_status" \
      --arg token_status "$token_status" \
      --arg account_slug "$account_slug" \
      --arg account_name "$account_name" \
      --arg expires_at "$expires_at" \
      --arg scope "$scope" \
      '{
        status: $status,
        token: $token_status,
        scope: (if $scope != "" then $scope else null end),
        account: {
          slug: (if $account_slug != "" then $account_slug else null end),
          name: (if $account_name != "" then $account_name else null end)
        },
        expires_at: (if $expires_at != "" and $expires_at != "0" and $expires_at != "null" then ($expires_at | tonumber) else null end)
      }'
  else
    echo "## Authentication Status"
    echo
    if [[ "$auth_status" == "authenticated" ]]; then
      echo "Status: ✓ Authenticated"
      [[ -n "$account_name" ]] && echo "Account: $account_name ($account_slug)" || true
      if [[ -n "$scope" ]]; then
        if [[ "$scope" == "read" ]]; then
          echo "Scope: $scope (read-only)"
        else
          echo "Scope: $scope (read+write)"
        fi
      fi
      if [[ "$token_status" == "long-lived" ]]; then
        echo "Token: ✓ Long-lived (no expiration)"
      elif [[ "$token_status" == "expired" ]]; then
        echo "Token: ⚠ Expired (run: fizzy auth login)"
      fi
    else
      echo "Status: ✗ Not authenticated"
      echo
      echo "Run: fizzy auth login"
    fi
  fi
}

_auth_refresh() {
  # First check if we're authenticated at all
  if ! get_access_token &>/dev/null; then
    die "Not authenticated. Run: fizzy auth login" $EXIT_AUTH
  fi

  # Check if we have a refresh token before attempting
  local creds
  creds=$(load_credentials)
  local refresh_tok
  refresh_tok=$(echo "$creds" | jq -r '.refresh_token // empty')

  if [[ -z "$refresh_tok" ]]; then
    # Fizzy issues long-lived tokens without refresh capability
    local expires_at
    expires_at=$(echo "$creds" | jq -r '.expires_at // "null"')
    # Treat null and 0 as long-lived (consistent with is_token_expired and auth status)
    if [[ "$expires_at" == "null" ]] || [[ "$expires_at" == "0" ]]; then
      info "Your token is long-lived and doesn't require refresh."
      _auth_status
      return 0
    else
      die "No refresh token available. Run: fizzy auth login" $EXIT_AUTH
    fi
  fi

  if refresh_token; then
    info "Token refreshed successfully"
    _auth_status
  else
    die "Token refresh failed. Run: fizzy auth login" $EXIT_AUTH
  fi
}


# OAuth Helpers

_register_client() {
  # Dynamic Client Registration (DCR) using discovered endpoint
  local registration_endpoint
  registration_endpoint=$(_registration_endpoint)

  if [[ -z "$registration_endpoint" ]]; then
    die "OAuth server does not support Dynamic Client Registration" $EXIT_AUTH \
      "The server's .well-known/oauth-authorization-server does not include registration_endpoint"
  fi

  debug "Registering client at: $registration_endpoint"

  # DCR clients typically only get authorization_code grant
  local grant_types='["authorization_code"]'

  # Fizzy DCR only supports public clients (no client_secret)
  # Request both read and write scopes so CLI can perform all operations
  local response
  response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg name "$FIZZY_CLIENT_NAME" \
      --arg uri "$FIZZY_CLIENT_URI" \
      --arg redirect "$FIZZY_REDIRECT_URI" \
      --argjson grants "$grant_types" \
      '{
        client_name: $name,
        client_uri: $uri,
        redirect_uris: [$redirect],
        grant_types: $grants,
        response_types: ["code"],
        token_endpoint_auth_method: "none",
        scope: "read write"
      }')" \
    "$registration_endpoint")

  local client_id client_secret
  client_id=$(echo "$response" | jq -r '.client_id // empty')
  client_secret=$(echo "$response" | jq -r '.client_secret // empty')

  if [[ -z "$client_id" ]]; then
    debug "DCR response: $response"
    return 1
  fi

  debug "Registered client_id: $client_id"

  # Save using multi-origin aware save_client from config.sh
  local client_json
  client_json=$(jq -n \
    --arg client_id "$client_id" \
    --arg client_secret "${client_secret:-}" \
    '{client_id: $client_id, client_secret: $client_secret}')
  save_client "$client_json"
}

_load_client() {
  # Use multi-origin aware load_client from config.sh
  local client_data
  client_data=$(load_client)

  client_id=$(echo "$client_data" | jq -r '.client_id // empty')
  client_secret=$(echo "$client_data" | jq -r '.client_secret // ""')

  # Only client_id is required (public clients may not have secret)
  [[ -n "$client_id" ]]
}

_generate_code_verifier() {
  # Generate random 43-128 character string for PKCE (RFC 7636)
  # Use extra bytes to ensure we have enough after removing invalid chars
  # Valid chars: [A-Za-z0-9._~-]
  local verifier
  while true; do
    verifier=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=' | cut -c1-43)
    if [[ ${#verifier} -ge 43 ]]; then
      echo "$verifier"
      return
    fi
  done
}

_generate_code_challenge() {
  local verifier="$1"
  # S256: BASE64URL(SHA256(verifier))
  echo -n "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='
}

_generate_state() {
  openssl rand -hex 16
}

_open_browser() {
  local url="$1"

  case "$(uname -s)" in
    Darwin) open "$url" ;;
    Linux)
      if command -v xdg-open &>/dev/null; then
        xdg-open "$url"
      elif command -v gnome-open &>/dev/null; then
        gnome-open "$url"
      else
        warn "Could not open browser automatically"
      fi
      ;;
    MINGW*|CYGWIN*) start "$url" ;;
    *) warn "Could not open browser automatically" ;;
  esac
}

_wait_for_callback() {
  local expected_state="$1"
  local timeout_secs=120

  # Check dependencies
  if ! command -v nc &>/dev/null; then
    die "netcat (nc) is required for OAuth callback" $EXIT_USAGE \
      "Install: brew install netcat (macOS) or apt install netcat (Linux)"
  fi

  if ! command -v timeout &>/dev/null && ! command -v gtimeout &>/dev/null; then
    die "timeout is required for OAuth callback" $EXIT_USAGE \
      "Install: brew install coreutils (macOS, provides gtimeout)"
  fi

  local timeout_cmd="timeout"
  command -v timeout &>/dev/null || timeout_cmd="gtimeout"

  info "Waiting for authorization (timeout: ${timeout_secs}s)..."

  # Create temp file for HTTP response (piping to nc doesn't block on macOS BSD nc)
  local http_response_file
  http_response_file=$(mktemp)
  printf 'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html><body><h1>Authorization successful!</h1><p>You can close this window.</p></body></html>' > "$http_response_file"

  local response exit_code=0
  response=$("$timeout_cmd" "$timeout_secs" bash -c '
    response_file="'"$http_response_file"'"
    port="'"$FIZZY_REDIRECT_PORT"'"
    request_file=$(mktemp)
    trap "rm -f $request_file" EXIT

    while true; do
      # Open response file for reading on fd3
      exec 3<"$response_file" || exit 1

      # nc -l PORT: listen for one connection
      # <&3 redirects stdin from fd3 (response file) - nc sends this to client
      # nc outputs what client sends (the HTTP request) to stdout
      # Capture to file to avoid SIGPIPE from head -1 killing nc before response is sent
      nc -l "$port" <&3 > "$request_file" 2>/dev/null

      # Close the file descriptor
      exec 3<&-

      # Read the first line (HTTP request line) from captured output
      request=$(head -1 "$request_file")

      if [[ "$request" == *"GET /callback"* ]]; then
        echo "$request"
        break
      fi

      # Small delay before retry to avoid tight loop
      sleep 0.1
    done
  ') || exit_code=$?

  rm -f "$http_response_file"

  if [[ -z "$response" ]] || [[ $exit_code -ne 0 ]]; then
    die "Authorization timed out" $EXIT_AUTH
  fi

  # Parse callback URL
  local query_string
  query_string=$(echo "$response" | sed -n 's/.*GET \/callback?\([^ ]*\).*/\1/p')

  local code state
  code=$(echo "$query_string" | tr '&' '\n' | grep '^code=' | cut -d= -f2)
  state=$(echo "$query_string" | tr '&' '\n' | grep '^state=' | cut -d= -f2)

  # URL decode the code (may contain encoded characters)
  code=$(printf '%b' "${code//%/\\x}")

  debug "Received auth code: $code"
  debug "Received state: $state"

  if [[ "$state" != "$expected_state" ]]; then
    die "State mismatch - possible CSRF attack" $EXIT_AUTH
  fi

  if [[ -z "$code" ]]; then
    local error
    error=$(echo "$query_string" | tr '&' '\n' | grep '^error=' | cut -d= -f2)
    die "Authorization failed: ${error:-unknown error}" $EXIT_AUTH
  fi

  echo "$code"
}

_exchange_code() {
  local code="$1"
  local code_verifier="$2"
  local client_id="$3"
  local client_secret="$4"

  local token_endpoint
  token_endpoint=$(_token_endpoint)

  debug "Exchanging code at: $token_endpoint"
  debug "Code verifier: $code_verifier"
  debug "Code verifier length: ${#code_verifier}"

  # Build curl args - only include client_secret for confidential clients
  local curl_args=(
    -s -X POST
    -H "Content-Type: application/x-www-form-urlencoded"
    --data-urlencode "grant_type=authorization_code"
    --data-urlencode "code=$code"
    --data-urlencode "redirect_uri=$FIZZY_REDIRECT_URI"
    --data-urlencode "client_id=$client_id"
    --data-urlencode "code_verifier=$code_verifier"
  )

  # Only include client_secret for confidential clients (non-empty secret)
  if [[ -n "$client_secret" ]]; then
    curl_args+=(--data-urlencode "client_secret=$client_secret")
  fi

  local response
  response=$(curl "${curl_args[@]}" "$token_endpoint")

  local access_token refresh_token expires_in scope
  access_token=$(echo "$response" | jq -r '.access_token // empty')
  refresh_token=$(echo "$response" | jq -r '.refresh_token // empty')
  expires_in=$(echo "$response" | jq -r '.expires_in // empty')
  scope=$(echo "$response" | jq -r '.scope // empty')

  if [[ -z "$access_token" ]]; then
    debug "Token response: $response"
    return 1
  fi

  # Build credentials - only include expires_at if server provided expires_in
  # Fizzy issues long-lived tokens without expiration
  local creds
  if [[ -n "$expires_in" ]]; then
    local expires_at
    expires_at=$(($(date +%s) + expires_in))
    creds=$(jq -n \
      --arg access_token "$access_token" \
      --arg refresh_token "$refresh_token" \
      --argjson expires_at "$expires_at" \
      --arg scope "$scope" \
      '{access_token: $access_token, refresh_token: $refresh_token, expires_at: $expires_at, scope: $scope}')
  else
    # No expiration - token is long-lived
    creds=$(jq -n \
      --arg access_token "$access_token" \
      --arg refresh_token "$refresh_token" \
      --arg scope "$scope" \
      '{access_token: $access_token, refresh_token: $refresh_token, expires_at: null, scope: $scope}')
  fi

  save_credentials "$creds"
}

_discover_accounts() {
  local token
  token=$(get_access_token) || return 1

  # Fizzy uses /my/identity to return accounts the user has access to
  local identity_endpoint="$FIZZY_BASE_URL/my/identity"

  debug "Fetching identity from: $identity_endpoint"

  local response http_code
  response=$(curl -s -w '\n%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "User-Agent: $FIZZY_USER_AGENT" \
    -H "Accept: application/json" \
    "$identity_endpoint")

  http_code=$(echo "$response" | tail -n1)
  response=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    debug "Identity fetch failed (HTTP $http_code): $response"
    return 1
  fi

  local accounts
  # Extract accounts from identity response; slug is the URL prefix (e.g., "/897362094")
  accounts=$(echo "$response" | jq '[.accounts[] | {id: .id, name: .name, slug: .slug, user: .user}]')

  if [[ "$accounts" != "[]" ]] && [[ "$accounts" != "null" ]]; then
    save_accounts "$accounts"
    return 0
  fi

  return 1
}

_select_account() {
  local accounts
  accounts=$(load_accounts)

  local count
  count=$(echo "$accounts" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    warn "No Fizzy accounts found"
    return
  fi

  if [[ "$count" -eq 1 ]]; then
    local account_slug account_name
    # Extract slug without leading slash
    account_slug=$(echo "$accounts" | jq -r '.[0].slug | ltrimstr("/")')
    account_name=$(echo "$accounts" | jq -r '.[0].name')
    set_global_config "account_slug" "$account_slug"
    info "Selected account: $account_name ($account_slug)"
  elif [[ "$count" -gt 1 ]]; then
    # Multiple accounts - let user choose
    echo "Multiple Fizzy accounts found:"
    echo
    echo "$accounts" | jq -r 'to_entries | .[] | "  \(.key + 1). \(.value.name) (\(.value.slug | ltrimstr("/")))"'
    echo

    local choice
    read -rp "Select account (1-$count): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      local account_slug account_name
      account_slug=$(echo "$accounts" | jq -r ".[$((choice - 1))].slug | ltrimstr(\"/\")")
      account_name=$(echo "$accounts" | jq -r ".[$((choice - 1))].name")
      set_global_config "account_slug" "$account_slug"
      info "Selected account: $account_name ($account_slug)"
    else
      warn "Invalid choice, using first account"
      local account_slug
      account_slug=$(echo "$accounts" | jq -r '.[0].slug | ltrimstr("/")')
      set_global_config "account_slug" "$account_slug"
    fi
  fi

  # Save the base URL so fizzy knows which server to talk to
  # This ensures tokens obtained from dev servers talk to dev servers
  set_global_config "base_url" "$FIZZY_BASE_URL"
  debug "Saved base URL: $FIZZY_BASE_URL"
}


# Help

_help_auth() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy auth",
      description: "Manage authentication",
      subcommands: [
        {name: "login", description: "Authenticate with Fizzy via OAuth 2.1"},
        {name: "logout", description: "Remove stored credentials"},
        {name: "status", description: "Show current authentication status"},
        {name: "refresh", description: "Check token status (Fizzy uses long-lived tokens)"}
      ],
      login_options: [
        {flag: "--scope", values: ["write", "read"], description: "Token scope (default: write)"},
        {flag: "--no-browser", description: "Manual auth code entry mode"}
      ],
      notes: ["Fizzy issues long-lived access tokens that do not expire"]
    }'
  else
    cat <<'EOF'
## fizzy auth

Manage authentication.

### Subcommands

- `login`   - Authenticate with Fizzy via OAuth 2.1
- `logout`  - Remove stored credentials
- `status`  - Show current authentication status
- `refresh` - Check token status (Fizzy uses long-lived tokens)

### Login Options

- `--scope write|read` - Token scope (default: write)
- `--no-browser`       - Manual auth code entry mode

### Notes

Fizzy issues long-lived access tokens that do not expire. You only need
to re-authenticate if you explicitly logout or revoke your token.

### Examples

```bash
# Interactive login (opens browser)
fizzy auth login

# Headless/SSH login
fizzy auth login --no-browser

# Read-only access
fizzy auth login --scope read

# Check status
fizzy auth status
```
EOF
  fi
}
