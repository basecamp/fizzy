module OauthHelper
  # Bidirectional controls can make a name read as something else, or push the
  # host beside it out of place. A self-registered name is the app's own claim,
  # so they go before it is shown anywhere.
  BIDI_CONTROLS = /[؜‎‏‪-‮⁦-⁩]/

  # Grouped by what the app is (Oauth::Client#connection_kind), in this order;
  # a group with nothing in it isn't shown.
  CONNECTED_APP_GROUPS = {
    web: "Apps and assistants on the web",
    local: "Apps on your devices",
    fizzy: "Fizzy apps"
  }

  ACCESS_LEVELS = {
    "read" => {
      label: "Read only",
      description: "See your boards, cards, comments and the people in your %{accounts}. It can't change anything."
    },
    "read write" => {
      label: "Read and write",
      description: "See everything you can, and act as you: create, edit, move, close and delete cards, comments and boards."
    }
  }

  # A name of nothing but direction controls is no name, so it reads as one.
  def oauth_client_self_name(client)
    client.name.to_s.gsub(BIDI_CONTROLS, "").presence || "Unnamed app"
  end

  # Who the person is dealing with, as far as we can vouch for it. A trusted or
  # operator-registered app is known by its name. A self-registered app's name
  # is only its claim, so it goes by where its access goes: the callback's
  # host, port included when it isn't the default, or this device.
  def oauth_client_display_identity(client, redirect_uri)
    if client.dynamically_registered?
      oauth_redirect_host(redirect_uri) || "an app on your device"
    else
      oauth_client_self_name(client)
    end
  end

  # Lowercase, as a browser reads it. nil for a callback that stays on this
  # device: loopback, or an app's own URL scheme.
  def oauth_redirect_host(redirect_uri)
    uri = URI.parse(redirect_uri.to_s)

    if uri.host.present? && !Oauth.loopback_host?(uri.host) && uri.scheme.to_s.downcase.in?(%w[ http https ])
      uri.port == uri.default_port ? uri.host.downcase : "#{uri.host.downcase}:#{uri.port}"
    end
  rescue URI::InvalidURIError
    nil
  end

  # Every place outside this device a client's access can go, as consent would
  # name each one. A client may register several callbacks, and its grants may
  # have come through any of them, so none speaks for the rest.
  def oauth_client_remote_hosts(client)
    client.redirect_uris.filter_map { |uri| oauth_redirect_host(uri) }.uniq
  end

  # The access levels a client may be granted, weakest first, each with what
  # it lets the app do in plain words. A grant reaches every account the
  # person belongs to, unless it's bound to the one picked at consent.
  def oauth_access_levels(client, one_account: false)
    levels = client.scopes.include?("write") ? ACCESS_LEVELS.keys : %w[ read ]

    levels.map do |scope|
      level = ACCESS_LEVELS.fetch(scope)
      [ scope, level.merge(description: format(level[:description], accounts: one_account ? "account" : "accounts")) ]
    end
  end

  def oauth_strongest_permission(tokens)
    if tokens.any?(&:write?)
      "write"
    elsif tokens.any?
      "read"
    end
  end

  def oauth_access_label(permission)
    ACCESS_LEVELS.fetch(Oauth.canonical_scope(permission))[:label]
  end

  # What an app's grants together let it do, as [ permission, accounts ]
  # pairs, accounts nil for every account the person belongs to. An unbound
  # grant reaches every account; a bound one adds only its own, and only
  # where it grants more, so no pair claims more than some grant gives.
  def oauth_connected_app_reach(tokens)
    # A grant bound to an account since deleted, cancelled, or left reaches
    # nothing: refreshing it would be refused, so it isn't shown as reach.
    unbound, bound = tokens.partition { |token| !token.account_bound? }
    active_account_ids = Current.identity.users_with_active_accounts.pluck(:account_id).to_set
    bound = bound.select { |token| token.account && active_account_ids.include?(token.account_id) }
    everywhere = oauth_strongest_permission(unbound)

    reach = bound.group_by(&:account).filter_map do |account, account_tokens|
      permission = oauth_strongest_permission(account_tokens)
      [ permission, account ] if everywhere.nil? || (permission == "write" && everywhere == "read")
    end

    [ (everywhere && [ everywhere, nil ]), *reach.group_by(&:first).map { |permission, pairs| [ permission, pairs.map(&:last) ] } ].compact
  end

  def connected_app_groups(connected_apps)
    by_kind = connected_apps.group_by { |client, _| client.connection_kind }

    CONNECTED_APP_GROUPS.filter_map do |kind, heading|
      [ kind, heading, by_kind[kind] ] if by_kind[kind].present?
    end
  end
end
