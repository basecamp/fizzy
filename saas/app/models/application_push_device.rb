class ApplicationPushDevice < ActionPushNative::Device
  belongs_to :session, optional: true

  def self.register(session:, token:, platform:, name: nil)
    session.identity.devices.find_or_initialize_by(token: token).tap do |device|
      device.update!(session: session, platform: platform.downcase, name: name)
    end
  end
end
