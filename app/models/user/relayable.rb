module User::Relayable
  extend ActiveSupport::Concern

  RELAY_LINK_EXPIRY_DURATION = 2.minutes

  class_methods do
    def find_by_relay_id(id)
      find_signed(id, purpose: :relay)
    end
  end

  def relay_id
    signed_id(purpose: :relay, expires_in: RELAY_LINK_EXPIRY_DURATION)
  end
end
