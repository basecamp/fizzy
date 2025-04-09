module Bubble::Pinnable
  extend ActiveSupport::Concern

  included do
    has_many :pins, dependent: :destroy
  end

  def pinned_by?(user)
    pins.exists?(user: user)
  end

  def pin_by(user)
    pins.find_or_create_by!(user: user)
  end

  def unpin_by(user)
    pins.find_by(user: user).tap { it.destroy }
  end
end
