# = Action Pack Passkey Request
#
# Controller concern that sets up the WebAuthn request context and provides
# helper methods for passkey registration and authentication. Include this
# in any controller that handles passkey form submissions.
#
# == Registration example
#
#   class PasskeysController < ApplicationController
#     include ActionPack::Passkey::Request
#
#     def new
#       @creation_options = passkey_creation_options(holder: Current.user)
#     end
#
#     def create
#       @passkey = ActionPack::Passkey.register(
#         passkey_creation_params, holder: Current.user
#       )
#       redirect_to settings_path
#     end
#   end
#
# == Authentication example
#
#   class SessionsController < ApplicationController
#     include ActionPack::Passkey::Request
#
#     def new
#       @request_options = passkey_request_options
#     end
#
#     def create
#       if passkey = ActionPack::Passkey.authenticate(passkey_request_params)
#         sign_in passkey.holder
#         redirect_to root_path
#       else
#         redirect_to new_session_path, alert: "Authentication failed"
#       end
#     end
#   end
#
# == Before Action
#
# Automatically populates +ActionPack::WebAuthn::Current+ with the request
# host, origin, and challenge (read from the encrypted cookie set by
# ChallengesController). The cookie is deleted after being read to prevent
# replay.
#
module ActionPack::Passkey::Request
  extend ActiveSupport::Concern

  included do
    before_action do
      ActionPack::WebAuthn::Current.host = request.host
      ActionPack::WebAuthn::Current.origin = request.base_url
      ActionPack::WebAuthn::Current.challenge = cookies.encrypted[ActionPack::Passkey::ChallengesController::COOKIE_NAME]
      cookies.delete(ActionPack::Passkey::ChallengesController::COOKIE_NAME)
    end
  end

  # Returns strong parameters for the passkey registration ceremony.
  def passkey_creation_params(param: :passkey)
    params.expect(param => [ :client_data_json, :attestation_object, transports: [] ])
  end

  # Returns strong parameters for the passkey authentication ceremony.
  def passkey_request_params(param: :passkey)
    params.expect(param => [ :id, :client_data_json, :authenticator_data, :signature ])
  end

  # Returns RequestOptions for the authentication ceremony.
  def passkey_request_options(**options)
    ActionPack::Passkey.request_options(**options)
  end

  # Returns CreationOptions for the registration ceremony.
  def passkey_creation_options(**options)
    ActionPack::Passkey.creation_options(**options)
  end
end
