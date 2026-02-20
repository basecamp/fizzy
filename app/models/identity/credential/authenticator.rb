class Identity::Credential::Authenticator < Data.define(:name, :icon)
  REGISTRY = Rails.application.config_for(:passkey_aaguids).each_with_object({}) do |(_key, attrs), hash|
    authenticator = new(name: attrs[:name], icon: attrs[:icon])
    attrs[:aaguids].each { |aaguid| hash[aaguid] = authenticator }
  end.freeze

  class << self
    def find_by_aaguid(aaguid)
      REGISTRY[aaguid]
    end
  end
end
