# Lets the configured reviewer identity sign in with its fixed code (see
# Identity::ReviewerSignIn). It acts only where the emailed code didn't match,
# so the normal path, its rate limit and its pending-email check all run first.
module Sessions::ReviewerSignIn
  private
    def invalid_code
      if identity = Identity::ReviewerSignIn.authenticate(email_address: email_address_pending_authentication, code: code)
        logger.struct(authentication: { reviewer_sign_in: { identity: { id: identity.id } } })
        sign_in MagicLink.new(identity: identity, purpose: :sign_in)
      else
        super
      end
    end
end
