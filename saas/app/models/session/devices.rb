module Session::Devices
  extend ActiveSupport::Concern

  included do
    has_many :devices, class_name: "ApplicationPushDevice", dependent: :destroy
  end
end
