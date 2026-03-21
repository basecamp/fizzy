# = Action Pack Passkey Challenges Controller
#
# Generates fresh WebAuthn challenges for passkey ceremonies. The companion
# JavaScript calls this endpoint before initiating a registration or
# authentication ceremony so that the challenge is issued just-in-time rather
# than embedded in the initial page load.
#
# The generated challenge is stored in an encrypted, HTTP-only, same-site
# cookie and simultaneously returned in the JSON response body. The cookie is
# consumed by ActionPack::Passkey::Request on the subsequent form submission.
#
# == Route
#
# By default mounted at +/rails/action_pack/passkey/challenge+ (configurable
# via +config.action_pack.passkey.routes_prefix+).
#
class ActionPack::Passkey::ChallengesController < ActionController::Base
  COOKIE_NAME = :action_pack_passkey_challenge

  include ActionPack::Passkey::Request

  # Generates a fresh challenge, stores it in an encrypted cookie, and returns
  # it as JSON. The cookie is consumed on the next passkey form submission.
  def create
    challenge = create_passkey_challenge

    cookies.encrypted[COOKIE_NAME] = { value: challenge, httponly: true, same_site: :strict, secure: !request.local? && request.ssl? }
    render json: { challenge: challenge }
  end

  private
    def create_passkey_challenge
      ActionPack::WebAuthn::PublicKeyCredential::Options.new(
        challenge_expiration: Rails.configuration.action_pack.web_authn.request_challenge_expiration
      ).challenge
    end
end
