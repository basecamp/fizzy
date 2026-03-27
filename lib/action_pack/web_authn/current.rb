# = Action Pack WebAuthn Current Attributes
#
# Thread-isolated request-scoped attributes for WebAuthn ceremonies. These are
# set automatically by ActionPack::Passkey::Request at the start of each
# request and consumed by the registration/authentication flows.
#
# == Attributes
#
# [+host+]
#   The relying party identifier (typically +request.host+). Used as the
#   default RelyingParty ID.
#
# [+origin+]
#   The expected origin (typically +request.base_url+). Validated against the
#   +origin+ field in the authenticator's client data.
#
class ActionPack::WebAuthn::Current < ActiveSupport::CurrentAttributes
  attribute :host, :origin
end
