class SingleSignOn::Authentication
  attr_reader :identity, :failure_message

  def initialize(claims)
    @claims = claims
  end

  def sign_in
    begin
      sign_in_within_transaction
    rescue ActiveRecord::RecordNotUnique
      sign_in_within_transaction
    end
  rescue ActiveRecord::RecordInvalid
    @identity = nil
    @failure_message = "#{SingleSignOn.provider_name} sent an email address that is not valid."
    false
  end

  def requires_signup_completion?
    identity.present? && !identity.users_with_active_accounts.exists? && SingleSignOn.account_creator?(claims.groups)
  end

  private
    attr_reader :claims

    # A savepoint makes the rollback work inside an outer transaction too.
    def sign_in_within_transaction
      @identity = @failure_message = nil

      Identity.transaction(requires_new: true) do
        identity = find_or_link_identity
        identity.join_accounts_joinable_by_single_sign_on(name: claims.name, groups: claims.groups)
        identity.update_roles_from_single_sign_on(claims.groups)

        if accessible?(identity)
          @identity = identity
        else
          fail_with "You do not have access to a Fizzy account. Ask an admin to add you."
        end
      end

      @identity.present?
    end

    def find_or_link_identity
      Identity.find_by_single_sign_on(claims) || link_identity_by_email_address
    end

    def link_identity_by_email_address
      if claims.email_verified?
        identity = Identity.find_or_create_by!(email_address: claims.email_address)

        if identity.single_sign_on_link_for(claims.issuer)
          fail_with "This email address is linked to a different #{SingleSignOn.provider_name} user. " \
            "Ask an admin for help."
        else
          identity.link_single_sign_on(claims)
          identity
        end
      else
        fail_with "Your email address is not confirmed in #{SingleSignOn.provider_name}. " \
          "Ask an admin to confirm it."
      end
    end

    def accessible?(identity)
      identity.users_with_active_accounts.exists? || SingleSignOn.account_creator?(claims.groups)
    end

    def fail_with(message)
      @failure_message = message
      raise ActiveRecord::Rollback
    end
end
