module Card::Pinnable
  extend ActiveSupport::Concern

  included do
    has_many :pins, dependent: :destroy

    after_update_commit :broadcast_pin_updates_later, if: :preview_changed?
  end

  def pinned_by?(user)
    pins.exists?(user: user)
  end

  def pin_for(user)
    pins.find_by(user: user)
  end

  def pin_by(user)
    pins.find_or_create_by!(user: user)
  end

  def unpin_by(user)
    pins.find_by(user: user).tap { it.destroy }
  end

  # Renders the board this run has loaded, so it picks its recipients from that same board:
  # a card that moves again while the job runs cannot widen the audience, and access revoked
  # before the job runs is already gone from board.users.
  def broadcast_pin_updates
    pins.where(user: board.users).find_each do |pin|
      pin.broadcast_replace_to [ pin.user, :pins_tray ], partial: "my/pins/pin"
    end
  end

  private
    def broadcast_pin_updates_later
      Card::BroadcastPinUpdatesJob.perform_later(self)
    end
end
