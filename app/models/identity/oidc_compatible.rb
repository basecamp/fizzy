module Identity::OidcCompatible
  extend ActiveSupport::Concern

  class_methods do
    def find_or_create_from_oidc(auth_hash)
      provider = auth_hash.provider
      subject = auth_hash.uid
      email = auth_hash.info.email
      email_verified = auth_hash.extra.raw_info.email_verified || false

      return nil unless subject.present? && email.present?

      # First, try to find existing identity by OIDC subject
      identity = find_by(oidc_subject: subject, oidc_provider: provider)

      if identity
        if email_verified && identity.email_address != email
          identity.update(email_address: email)
        end
        return identity
      end

      # Next, try to find by email and link OIDC credentials
      identity = find_by(email_address: email)

      if identity
        identity.update(
          oidc_subject: subject,
          oidc_provider: provider
        )
        return identity
      end

      # Create new identity with OIDC
      create(
        email_address: email,
        oidc_subject: subject,
        oidc_provider: provider
      )
    end
  end
end
