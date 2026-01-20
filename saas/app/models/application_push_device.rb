class ApplicationPushDevice < ActionPushNative::Device
  def self.register(owner:, token:, platform:, name: nil)
    owner.devices.find_or_initialize_by(token: token).tap do |device|
      device.update!(platform: platform.downcase, name: name)
    end
  end
end
