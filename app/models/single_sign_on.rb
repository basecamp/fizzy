module SingleSignOn
  DEFAULT_PROVIDER_NAME = "SSO"
  DEFAULT_REAUTHENTICATION_HOURS = 12
  FULL_GROUP_PATH = %r{\A(/[^/]+)+\z}
  GROUP_LENGTH_LIMIT = 255

  class ConfigurationError < StandardError; end

  class Error < StandardError; end
  class ProviderError < Error; end
  class AuthorizationError < Error; end
  class InvalidIdToken < Error; end

  class << self
    def configured?
      credentials.all?(&:present?)
    end

    def provider
      Provider.new \
        issuer: settings.issuer,
        client_id: settings.client_id,
        client_secret: settings.client_secret
    end

    def provider_name
      settings.provider_name.presence || DEFAULT_PROVIDER_NAME
    end

    def reauthentication_period
      reauthentication_hours.hours
    end

    def admin_group
      settings.admin_group&.strip.presence
    end

    def account_admin_subgroup
      settings.account_admin_subgroup&.strip.presence
    end

    def admin?(groups)
      admin_group.present? && member?(groups, admin_group)
    end

    # Without an admin group, nobody can create an account after the first one.
    def account_creator?(groups)
      if admin_group
        admin?(groups)
      else
        Account.none?
      end
    end

    # Providers can list only direct memberships, so a member of a subgroup also counts as a member of its parents.
    def member?(groups, group)
      groups.any? { |candidate| candidate == group || candidate.start_with?("#{group}/") }
    end

    def full_group_path?(group)
      FULL_GROUP_PATH.match?(group)
    end

    def secure_url?(url)
      uri = URI.parse(url.to_s)
      uri.host.present? && (uri.scheme == "https" || (uri.scheme == "http" && Rails.env.local?))
    rescue URI::InvalidURIError
      false
    end

    def groups_with_parents(groups)
      groups.flat_map do |group|
        names = group.split("/").drop(1)
        names.size.times.map { |depth| "/#{names.first(depth + 1).join("/")}" }
      end.uniq
    end

    def ensure_valid_configuration
      ensure_complete_credentials
      ensure_secure_issuer
      ensure_full_admin_group_path
      ensure_relative_account_admin_subgroup
      reauthentication_hours
    end

    private
      def settings
        Rails.configuration.x.single_sign_on
      end

      def credentials
        [ settings.issuer, settings.client_id, settings.client_secret ]
      end

      def reauthentication_hours
        hours = settings.reauthentication_hours || DEFAULT_REAUTHENTICATION_HOURS

        if (hours = Integer(hours.to_s, 10, exception: false)) && hours >= 1
          hours
        else
          raise ConfigurationError,
            "SINGLE_SIGN_ON_REAUTHENTICATION_HOURS must be a whole number of 1 or more"
        end
      end

      def ensure_complete_credentials
        if credentials.any?(&:present?) && !configured?
          raise ConfigurationError, "Single sign-on configuration is incomplete. " \
            "Set SINGLE_SIGN_ON_ISSUER, SINGLE_SIGN_ON_CLIENT_ID, " \
            "and SINGLE_SIGN_ON_CLIENT_SECRET"
        end
      end

      def ensure_secure_issuer
        if configured? && !issuer_url?(settings.issuer)
          raise ConfigurationError, "SINGLE_SIGN_ON_ISSUER must be an https URL with no query, fragment, or credentials, " \
            "such as https://id.example.com"
        end
      end

      # OpenID Connect issuers have no query or fragment, and the CSP header copies any credentials in the URL.
      def issuer_url?(url)
        secure_url?(url) && URI.parse(url).then { |uri| uri.query.nil? && uri.fragment.nil? && uri.userinfo.nil? }
      end

      def ensure_full_admin_group_path
        if admin_group && !(full_group_path?(admin_group) && admin_group.length <= GROUP_LENGTH_LIMIT)
          raise ConfigurationError, "SINGLE_SIGN_ON_ADMIN_GROUP must be a full group path of #{GROUP_LENGTH_LIMIT} characters or fewer, " \
            "such as /fizzy/admin"
        end
      end

      def ensure_relative_account_admin_subgroup
        if account_admin_subgroup && !full_group_path?("/#{account_admin_subgroup}")
          raise ConfigurationError, "SINGLE_SIGN_ON_ACCOUNT_ADMIN_SUBGROUP must be a relative group path, such as admin"
        end
      end
  end
end
