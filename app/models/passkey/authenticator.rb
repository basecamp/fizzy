class Passkey::Authenticator < Data.define(:aaguids, :name, :icon)
  class << self
    def find_by_aaguid(aaguid)
      registry[aaguid]
    end

    def registry
      @registry ||= Hash.new.tap do |registry|
        all.each do |authenticator|
          authenticator.aaguids.each do |aaguid|
            registry[aaguid] = authenticator
          end
        end
      end
    end

    def all
      Rails.application.config_for(:passkey_aaguids).each_value.map do |attrs|
        new(aaguids: attrs[:aaguids], name: attrs[:name], icon: attrs[:icon])
      end
    end
  end
end
