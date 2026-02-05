module ActionPack::WebAuthn
  class << self
    def relying_party
      RelyingParty.new
    end
  end
end
