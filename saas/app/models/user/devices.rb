module User::Devices
  extend ActiveSupport::Concern

  included do
    has_many :devices, class_name: "ActionPushNative::Device", as: :owner, dependent: :destroy
  end
end
