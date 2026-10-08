class SingleSignOn::Claims < Data.define(:issuer, :subject, :email_address, :email_verified, :name, :groups)
  NAME_LENGTH_LIMIT = 240
  GROUPS_LIMIT = 256

  class << self
    def from_payload(payload)
      new \
        issuer: payload["iss"],
        subject: payload["sub"],
        email_address: payload["email"].presence,
        email_verified: payload["email_verified"],
        name: name_from(payload),
        groups: groups_from(payload)
    end

    private
      def name_from(payload)
        name = payload["name"].presence ||
          [ payload["given_name"], payload["family_name"] ].compact_blank.join(" ")

        name.to_s.squish.first(NAME_LENGTH_LIMIT).presence
      end

      # Providers without nested groups send plain names, so a name without a leading slash is a top-level group.
      # Dropping paths over the length limit bounds the work for parent groups, but membership in their parents is lost too.
      def groups_from(payload)
        Array(payload["groups"]).grep(String).compact_blank
          .map { |group| group.start_with?("/") ? group : "/#{group}" }
          .select { |group| group.length <= SingleSignOn::GROUP_LENGTH_LIMIT }
          .uniq.first(GROUPS_LIMIT)
      end
  end

  def initialize(groups: [], **attributes)
    super
  end

  def email_verified?
    email_verified == true && email_address.present?
  end
end
