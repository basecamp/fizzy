# Fixed sign-in codes for named reviewer identities: the ones the AI directory
# listings (Claude, ChatGPT and the rest) and the app stores sign in as. Their
# reviewers sign in from fresh browsers and can't read the reviewer's inbox for
# the emailed code, and Fizzy has no password to give them.
#
# A reviewer enters its identity's email address as anyone does, then its code
# in place of the emailed one. Nothing else changes: the emailed code still
# works, and every other identity signs in exactly as before.
#
# Each directory partner gets an identity, and a code, of its own, so one
# partner's review, rotation or cleanup never touches another's connection
# (a scanner that runs on a schedule keeps an identity of its own too).
# FIZZY_REVIEWER_SIGN_IN_CODES lists them as email=digest pairs, separated by
# commas or spaces. The single FIZZY_REVIEWER_SIGN_IN_EMAIL and
# FIZZY_REVIEWER_SIGN_IN_CODE_DIGEST pair still configures one more, and the
# list wins where both name an address. Only each code's SHA-256 digest is
# configured, never the code. Generate a code, and the list with it added, with
# `bin/rails saas:reviewer_sign_in:generate EMAIL=reviewer@example.com`, which
# prints a random 16-character code (80 bits). Rotate a code after each review.
#
# An address listed with an empty digest is still a reviewer, for the locks,
# the staff-only OAuth exemption and sign-out, but no code signs it in.
#
# Reviewers pass the staff-only OAuth gate (Oauth::Availability.admits?) so
# their apps connect while OAuth is otherwise limited to staff. They are not
# staff, so /admin stays closed to them.
#
# For a reviewer the code is the only gate, so its security is exactly the
# code's. Keep each reviewer in its own comped, internal account. Rotate by
# generating a new code, replacing the digest, then running
# `bin/rails saas:reviewer_sign_in:sign_out EMAIL=reviewer@example.com` to end
# the old code's sessions. That task also lists every active member of the
# reviewer's accounts and every app connected to it: check them after each
# review, deactivate anyone who isn't the reviewer or the account's own staff,
# and disconnect any app that isn't the partner's, since a code holder could
# have joined under an identity of their own, or connected an app of their own,
# while the review ran.
module Identity::ReviewerSignIn
  CODE_LENGTH = 16

  class << self
    def authenticate(email_address:, code:)
      if reviewer_email_address = matching_email_address(email_address, code)
        Identity.find_by(email_address: reviewer_email_address).tap do |identity|
          record_use(identity) if identity
        end
      end
    end

    # Ends every session the reviewers have (or the one reviewer named), however
    # they signed in, closes their open Action Cable connections, and removes the
    # personal access tokens, passkeys and pending session transfers a code
    # holder could have added to get back in. It also resets the join codes of
    # the reviewers' accounts, so a code holder who read one can't join under an
    # identity of their own. Run it when rotating a code, so sessions started
    # with the old one end too. It needs only the email, so it still works
    # after the digest is cleared.
    #
    # It leaves OAuth grants alone. The partner's own app connects as the
    # reviewer and keeps working between reviews (a daily directory scan, say),
    # and a sign-out that disconnected it would end the listing's access. Check
    # the grants it lists and disconnect a stranger's with revoke_oauth_grants.
    #
    # Reviewers can't move their users to another email address (see
    # User::ReviewerEmailAddressLock), so the configured email always finds
    # the identity and the accounts it signs in to.
    def sign_out_everywhere(email_address = nil)
      reviewer_identities(email_address).sum do |identity|
        identity.access_tokens.personal.destroy_all
        identity.passkeys.destroy_all
        identity.transfers.delete_all
        identity.accounts.each { |account| account.join_code&.reset }
        identity.sessions.destroy_all.size.tap { identity.close_remote_connections }
      end
    end

    # Disconnects every app connected as the one reviewer named: the explicit
    # cleanup for a grant a code holder left behind, or to reset a partner's
    # connection. It never runs as part of signing out, and it needs an
    # address, so it can't disconnect every partner at once.
    def revoke_oauth_grants(email_address)
      if email_address.present?
        reviewer_identities(email_address).sum do |identity|
          identity.access_tokens.grants.to_a.each { |grant| grant.revoke reason: "reviewer_cleanup", actor: "admin" }.size
        end
      else
        0
      end
    end

    # Every active member of the reviewers' accounts, by account, for the
    # after-review check: anyone here who isn't a reviewer or the account's own
    # staff joined during a review and keeps access until deactivated.
    def members_of_reviewer_accounts(email_address = nil)
      reviewer_identities(email_address).flat_map(&:accounts).uniq.to_h do |account|
        [ account, account.users.active.includes(:identity).order(:created_at).to_a ]
      end
    end

    # The apps connected as each reviewer, by identity, for the after-review
    # check: a grant to anything but the partner's own app is a code holder's.
    def oauth_grants_of_reviewers(email_address = nil)
      reviewer_identities(email_address).to_h do |identity|
        [ identity, identity.access_tokens.grants.includes(:oauth_client).order(:created_at).to_a ]
      end
    end

    def reviewer?(identity)
      identity.present? && code_digests.key?(identity.email_address)
    end

    def configured?
      code_digests.values.any?(&:present?)
    end

    # The FIZZY_REVIEWER_SIGN_IN_CODES value with this reviewer's digest added,
    # or replaced if it's already listed. Reviewers configured by the single
    # pair are carried into it, so the list alone can replace the pair.
    def code_digests_with(email_address, digest)
      code_digests.merge(email_address.to_s.strip.downcase => digest).map { |email, code_digest| "#{email}=#{code_digest}" }.join(",")
    end

    def digest(code)
      OpenSSL::Digest::SHA256.hexdigest(MagicLink::Code.sanitize(code).to_s)
    end

    def generate_code
      MagicLink::Code.generate(CODE_LENGTH)
    end

    private
      # Compares the presented address and code with every reviewer's, without
      # stopping at the first difference, so the time it takes doesn't tell
      # which part of which reviewer's matched.
      def matching_email_address(email_address, code)
        if email_address.present? && MagicLink::Code.sanitize(code).present?
          presented_email_address = email_address.to_s.downcase
          presented_digest = digest(code)

          code_digests.select do |reviewer_email_address, code_digest|
            [ code_digest.present?,
              ActiveSupport::SecurityUtils.secure_compare(presented_email_address, reviewer_email_address),
              ActiveSupport::SecurityUtils.secure_compare(presented_digest, code_digest) ].all?
          end.keys.first
        end
      end

      def record_use(identity)
        Sentry.capture_message "Reviewer sign-in code used", level: :info if defined?(Sentry)
      end

      # Only configured reviewers, so naming any other address finds no one.
      def reviewer_identities(email_address = nil)
        reviewer_email_addresses = code_digests.keys
        reviewer_email_addresses &= [ email_address.to_s.strip.downcase ] if email_address.present?

        Identity.where(email_address: reviewer_email_addresses).order(:id).to_a
      end

      # Each reviewer's email address, downcased, to its code digest, which is
      # empty for a reviewer whose code is turned off.
      def code_digests
        single_pair_code_digest.merge(listed_code_digests)
      end

      def listed_code_digests
        config.code_digests.to_s.split(/[\s,]+/).filter_map do |entry|
          email_address, separator, code_digest = entry.rpartition("=")
          email_address, code_digest = entry, "" if separator.empty?

          [ email_address.strip.downcase, code_digest.strip.downcase ] if email_address.present?
        end.to_h
      end

      def single_pair_code_digest
        if email_address = config.email_address.presence
          { email_address.strip.downcase => config.code_digest.to_s.strip.downcase }
        else
          {}
        end
      end

      def config
        Rails.application.config.x.reviewer_sign_in
      end
  end
end
