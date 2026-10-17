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
# while issuance is paused (minting endpoints answer 503); a dark server answers
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
module Oauth::Availability
  extend self

  def acceptance_enabled?(client_id = nil)
    accepting? || piloted?(client_id)
  end

  def issuance_enabled?(client_id = nil)
    acceptance_enabled?(client_id) && (issuing? || piloted?(client_id))
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

    def pilot_client_ids
      Array(config.pilot_client_ids)
    end

    def config
      Rails.application.config.x.oauth
    end
end
