# Availability switches for the OAuth authorization server, so it can ship dark.
#
# - acceptance: whether Fizzy honors the OAuth tokens it issued
# - issuance: whether Fizzy mints new credentials (client registrations,
#   authorization codes, tokens)
#
# Issuance is subordinate to acceptance: Fizzy never issues a credential it
# would refuse to accept. Personal access tokens are not OAuth credentials and
# neither switch touches them.
#
# Acceptance is fail-closed: anything but an explicit true is dark, so an
# install that never mentions OAuth (every OSS install, and SaaS until it is
# lit) answers as if it had no authorization server. Issuance is the incident
# pause, so it follows acceptance unless explicitly turned off. See
# config/environments/production.rb for the environment variables.
#
# Discovery follows acceptance: a server that honors tokens stays discoverable
# while issuance is paused (minting endpoints, refresh included, answer 503, so
# access tokens already issued work until they expire); a dark server answers
# 404 to discovery and minting alike.
#
# Management is never gated: revocation, Connected Apps and authorization
# denials stay reachable while dark or paused, so people can always shed access.
#
# == Piloting against a dark server
#
# Named clients, by exact client_id, are exempt from both switches so
# first-party software can exercise the real server before it opens to
# everyone. Only surfaces that know which client is asking honor it: discovery
# names no client and stays dark, and so does registration, so a pilot uses an
# operator-provisioned client. The exemption reads the claimed client_id before
# the client authenticates; it decides only whether the endpoint answers, and
# leaving with a credential still takes the registered redirect_uri, PKCE, a
# signed-in user's consent and, for a confidential client, its secret.
#
# An incident pause must therefore empty pilot_client_ids as well as throwing
# the switch, or listed clients keep minting through it.
#
# == Connected apps preview
#
# The switches above choose clients. The connected apps preview chooses
# people: while it's on, only previewers can connect an app, redeem a code,
# refresh, or use an OAuth token, whichever client asks. Previewers are
# 37signals staff (Identity#staff?) and reviewers: the identities whose ids
# config.x.oauth.connected_apps_preview_reviewer_ids lists, and anyone an
# extension admits with admit_as_reviewer, a predicate on the identity. A
# reviewer gets exactly what staff get here, and nothing beyond it: reviewers
# aren't staff, so /admin stays closed to them. Someone who stops being a
# previewer loses the access they granted on their next request. Personal
# access tokens are not OAuth credentials, so the preview doesn't touch them,
# and management stays open to everyone, so anyone can still shed a grant.
#
# The SaaS engine admits the directory reviewers it signs in
# (Identity::ReviewerSignIn). Fizzy itself registers no extension and lists no
# reviewer ids, so an install that configures neither previews to staff alone.
# See config/environments/production.rb for the environment variables.
module Oauth::Availability
  extend self

  # An identity id is a UUID written in base36 (ActiveRecord::Type::Uuid).
  IDENTITY_ID = /\A[0-9a-z]{#{ActiveRecord::Type::Uuid::BASE36_LENGTH}}\z/

  mattr_accessor :reviewer_predicates, default: []

  def acceptance_enabled?(client_id = nil)
    accepting? || piloted?(client_id)
  end

  def issuance_enabled?(client_id = nil)
    acceptance_enabled?(client_id) && (issuing? || piloted?(client_id))
  end

  # Client ID Metadata Documents, fail-closed: only an explicit true turns them
  # on, and they never outrun issuance. Intake only: a metadata document client
  # already authorized keeps refreshing while this is off.
  def metadata_documents_enabled?(client_id = nil)
    issuance_enabled?(client_id) && config.cimd_enabled == true
  end

  def connected_apps_preview?
    config.connected_apps_preview == true
  end

  # Whether OAuth is open to this person: everyone, unless connecting apps is
  # in preview, and then previewers alone.
  def admits?(identity)
    !connected_apps_preview? || previewer?(identity)
  end

  def previewer?(identity)
    identity.present? && (identity.staff? == true || reviewer?(identity))
  end

  def admit_as_reviewer(predicate)
    reviewer_predicates << predicate unless reviewer_predicates.include?(predicate)
  end

  # Whether the preview is on, from CONNECTED_APPS_PREVIEW, or from its old
  # name, OAUTH_STAFF_ONLY, while the new one is unset or blank, so a
  # destination still deployed with the old name stays in preview rather than
  # opening. Neither set means off, as OAUTH_STAFF_ONLY unset always did.
  # TODO: drop OAUTH_STAFF_ONLY once every destination has deployed with
  # CONNECTED_APPS_PREVIEW.
  def connected_apps_preview_from(env)
    (env["CONNECTED_APPS_PREVIEW"].presence || env["OAUTH_STAFF_ONLY"]) == "true"
  end

  # The reviewer identity ids in CONNECTED_APPS_PREVIEW_REVIEWERS, separated by
  # commas or spaces. Unset or empty lists none. An entry that isn't an
  # identity id (an email address, say) is skipped rather than failing the
  # boot, and reported as oauth.preview.reviewers_skipped (Oauth::Audit), which
  # the SaaS engine writes to the structured log whatever RAILS_LOG_LEVEL is.
  # Both the report and the log warning count entries and never echo them.
  def reviewer_ids_from(value)
    entries = value.to_s.split(/[\s,]+/).compact_blank.map(&:downcase)
    ids, rejected = entries.partition { |entry| entry.match?(IDENTITY_ID) }

    if rejected.any?
      Rails.logger.warn "CONNECTED_APPS_PREVIEW_REVIEWERS: skipping entries that aren't identity ids (#{rejected.size})"
      Oauth::Audit.record "preview.reviewers_skipped", actor: "system", reason: "not_an_identity_id", skipped: rejected.size
    end

    ids.uniq.freeze
  end

  # The clients whose tokens are honored, as a relation, for code that weighs
  # many grants at once rather than one presented token.
  def accepted_clients
    accepting? ? Oauth::Client.all : Oauth::Client.where(client_id: pilot_client_ids)
  end

  private
    def accepting?
      config.acceptance_enabled == true
    end

    def issuing?
      config.issuance_enabled != false
    end

    def piloted?(client_id)
      client_id.is_a?(String) && client_id.present? && pilot_client_ids.include?(client_id)
    end

    def reviewer?(identity)
      reviewer_ids.include?(identity.id) || reviewer_predicates.any? { |predicate| predicate.call(identity) == true }
    end

    def reviewer_ids
      Array(config.connected_apps_preview_reviewer_ids)
    end

    def pilot_client_ids
      Array(config.pilot_client_ids)
    end

    def config
      Rails.application.config.x.oauth
    end
end
