# = Action Pack WebAuthn Relying Party
#
# Represents the relying party (your application) in WebAuthn ceremonies. The
# relying party identity is sent to authenticators during registration and
# authentication to scope credentials to your application.
#
# == Usage
#
#   # Using defaults (host from Current, name from Rails application)
#   relying_party = ActionPack::WebAuthn::RelyingParty.new
#
#   # With explicit values
#   relying_party = ActionPack::WebAuthn::RelyingParty.new(
#     id: "example.com",
#     name: "Example Application"
#   )
#
# == Attributes
#
# [+id+]
#   The relying party identifier, typically the application's domain name
#   (e.g., "example.com"). This must match the origin's effective domain
#   or be a registrable domain suffix of it. Credentials are scoped to this
#   identifier. Defaults to +ActionPack::WebAuthn::Current.host+.
#
# [+name+]
#   A human-readable name for your application, displayed by authenticators
#   during ceremonies. Defaults to +Rails.application.name+.
class ActionPack::WebAuthn::RelyingParty
  attr_reader :id, :name

  # Creates a new relying party configuration.
  #
  # ==== Options
  #
  # [+:id+]
  #   Optional. The relying party identifier (domain).
  #
  # [+:name+]
  #   Optional. The application display name.
  def initialize(id: ActionPack::WebAuthn::Current.host, name: Rails.application.name)
    @id = id
    @name = name
  end

  # Returns a Hash suitable for JSON serialization.
  def as_json(*)
    { id: id, name: name }
  end
end
