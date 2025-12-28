# rbs_inline: enabled

module Card::Pinnable
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Pinnable)

  included do
    has_many :pins, dependent: :destroy

    after_update_commit :broadcast_pin_updates, if: :preview_changed?
  end

  #: (User) -> bool
  def pinned_by?(user)
    # @type self: Card & Card::Pinnable
    pins.exists?(user: user)
  end

  #: (User) -> Pin?
  def pin_for(user)
    # @type self: Card & Card::Pinnable
    pins.find_by(user: user)
  end

  #: (User) -> Pin
  def pin_by(user)
    # @type self: Card & Card::Pinnable
    pins.find_or_create_by!(user: user)
  end

  #: (User) -> void
  def unpin_by(user)
    # @type self: Card & Card::Pinnable
    pins.find_by!(user: user).tap do |it|
      it.destroy
    end
  end

  private
    #: -> void
    def broadcast_pin_updates
      # @type self: Card & Card::Pinnable
      pins.find_each do |pin|
        pin.broadcast_replace_later_to [ pin.user, :pins_tray ], partial: "my/pins/pin"
      end
    end
end
