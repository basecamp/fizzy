class ActionPack::WebAuthn::Current < ActiveSupport::CurrentAttributes
  attribute :host, :origin
end
