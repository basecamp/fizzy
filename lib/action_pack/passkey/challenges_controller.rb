class ActionPack::Passkey::ChallengesController < ActionController::Base
  include ActionPack::Passkey::Request

  def create
    challenge = ActionPack::WebAuthn::PublicKeyCredential::Options.new(
      challenge_expiration: Rails.configuration.action_pack.web_authn.request_challenge_expiration
    ).challenge

    cookies.encrypted[:webauthn_challenge] = { value: challenge, httponly: true, same_site: :strict }

    render json: { challenge: challenge }
  end
end
