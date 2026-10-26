# A fixed sign-in code for exactly one identity: the shared reviewer that the
# AI directory listings (Claude, ChatGPT) and the app stores sign in as. Their
# reviewers sign in from fresh browsers and can't read the reviewer's inbox for
# the emailed code, and Fizzy has no password to give them.
#
# The reviewer enters the identity's email address as anyone does, then this
# code in place of the emailed one. Nothing else changes: the emailed code
# still works, and every other identity signs in exactly as before.
#
# Off unless both FIZZY_REVIEWER_SIGN_IN_EMAIL and
# FIZZY_REVIEWER_SIGN_IN_CODE_DIGEST are set. Only the code's SHA-256 digest is
# configured, never the code. Generate both with
# `bin/rails saas:reviewer_sign_in:generate`, which prints a random 16-character
# code (80 bits) and its digest. Rotate the code after each review.
#
# For that one identity the code is the only gate, so its security is exactly
# the code's. Keep the identity in its own comped, internal account. Rotate by
# generating a new code, replacing the digest, then running
# `bin/rails saas:reviewer_sign_in:sign_out` to end the old code's sessions.
# That task also lists every active member of the reviewer's accounts: check it
# after each review and deactivate anyone who isn't the reviewer or the
# account's own staff, since a code holder could have joined under an identity
# of their own while the review ran.
module Identity::ReviewerSignIn
  CODE_LENGTH = 16

  class << self
    def authenticate(email_address:, code:)
      if matches?(email_address, code)
        configured_identity.tap do |identity|
          record_use(identity) if identity
        end
      end
    end

    # Ends every session the configured identity has, however it signed in,
    # closes its open Action Cable connections, and removes the access tokens,
    # passkeys and pending session transfers a code holder could have added to
    # get back in. It also resets the join codes of the reviewer's accounts, so
    # a code holder who read one can't join under an identity of their own.
    # Run it when rotating the code, so sessions started with the old one end
    # too. It needs only the email, so it still works after the digest is
    # cleared.
    #
    # The reviewer can't move its users to another email address (see
    # User::ReviewerEmailAddressLock), so the configured email always finds
    # the identity and the accounts it signs in to.
    def sign_out_everywhere
      if identity = configured_identity
        identity.access_tokens.destroy_all
        identity.passkeys.destroy_all
        identity.transfers.delete_all
        identity.accounts.each { |account| account.join_code&.reset }
        identity.sessions.destroy_all.size.tap { identity.close_remote_connections }
      else
        0
      end
    end

    # Every active member of the reviewer's accounts, by account, for the
    # after-review check: anyone here who isn't the reviewer or the account's
    # own staff joined during a review and keeps access until deactivated.
    def members_of_reviewer_accounts
      if identity = configured_identity
        identity.accounts.to_h { |account| [ account, account.users.active.includes(:identity).order(:created_at).to_a ] }
      else
        {}
      end
    end

    def reviewer?(identity)
      configured_email_address.present? && identity.present? && identity.email_address == configured_email_address.downcase
    end

    def configured?
      configured_email_address.present? && configured_code_digest.present?
    end

    def digest(code)
      OpenSSL::Digest::SHA256.hexdigest(MagicLink::Code.sanitize(code).to_s)
    end

    def generate_code
      MagicLink::Code.generate(CODE_LENGTH)
    end

    private
      def matches?(email_address, code)
        configured? && \
          email_address.present? && MagicLink::Code.sanitize(code).present? && \
          ActiveSupport::SecurityUtils.secure_compare(email_address.to_s.downcase, configured_email_address.downcase) && \
          ActiveSupport::SecurityUtils.secure_compare(digest(code), configured_code_digest.downcase)
      end

      def record_use(identity)
        Sentry.capture_message "Reviewer sign-in code used", level: :info if defined?(Sentry)
      end

      def configured_identity
        Identity.find_by(email_address: configured_email_address) if configured_email_address.present?
      end

      def configured_email_address
        config.email_address.presence
      end

      def configured_code_digest
        config.code_digest.presence
      end

      def config
        Rails.application.config.x.reviewer_sign_in
      end
  end
end
