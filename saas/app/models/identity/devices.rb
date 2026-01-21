module Identity::Devices
  extend ActiveSupport::Concern

  included do
    has_many :devices, class_name: "ApplicationPushDevice", as: :owner, dependent: :destroy
  end
end
