module User::SignalUser
  extend ActiveSupport::Concern

  included do
    unless Rails.application.config.x.local_authentication
      belongs_to :signal_user, dependent: :destroy, class_name: "SignalId::User", optional: true
    end
  end
end
