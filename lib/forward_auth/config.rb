# frozen_string_literal: true

module ForwardAuth
  class Config
    VALID_ROLES = %w[ owner admin member system ].freeze

    attr_reader :enabled, :trusted_ips, :secret_header, :secret,
                :auto_provision, :default_role, :create_session,
                :use_email_local_part_and_lock_email,
                :auto_create_account, :auto_create_account_name

    def initialize(
      enabled: false,
      trusted_ips: [],
      secret_header: nil,
      secret: nil,
      auto_provision: false,
      default_role: "member",
      create_session: true,
      use_email_local_part_and_lock_email: false,
      auto_create_account: true,
      auto_create_account_name: "My Workspace"
    )
      @enabled = enabled
      @trusted_ips = build_trusted_ip_list(trusted_ips)
      @secret_header = secret_header
      @secret = secret
      @auto_provision = auto_provision
      @default_role = VALID_ROLES.include?(default_role) ? default_role : "member"
      @create_session = create_session
      @use_email_local_part_and_lock_email = use_email_local_part_and_lock_email
      @auto_create_account = auto_create_account
      @auto_create_account_name = auto_create_account_name.to_s.strip.presence || "My Workspace"
    end

    def enabled?
      enabled
    end

    def auto_provision?
      auto_provision
    end

    def create_session?
      create_session
    end

    def use_email_local_part_and_lock_email?
      use_email_local_part_and_lock_email
    end

    def auto_create_account?
      auto_create_account
    end

    # Returns true only when the request is from a trusted source (IP and/or secret header).
    # When Forward Auth is disabled, always returns false.
    # When enabled, at least one trust mechanism must be configured (trusted_ips or secret header);
    # otherwise no request is trusted (avoids trusting all IPs by mistake).
    def trusted?(request)
      return false unless enabled?
      return false if trusted_ips.empty? && (secret_header.blank? || secret.blank?)

      remote_ip = request.remote_ip.to_s.strip
      return false if remote_ip.blank?

      client_ip = IPAddr.new(remote_ip)
      ip_trusted = trusted_ips.empty? || trusted_ips.any? { |net| net.include?(client_ip) }
      secret_ok = secret_header.blank? || secret.blank? ||
                  ActiveSupport::SecurityUtils.secure_compare(
                    request.headers[secret_header].to_s,
                    secret
                  )

      ip_trusted && secret_ok
    rescue ArgumentError
      false
    end

    private

    def build_trusted_ip_list(entries)
      entries.filter_map do |entry|
        entry = entry.to_s.strip
        next if entry.blank?

        IPAddr.new(entry)
      rescue ArgumentError
        Rails.logger.warn "[ForwardAuth] Invalid trusted IP or CIDR: #{entry}"
        nil
      end
    end
  end
end
