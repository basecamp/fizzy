# rbs_inline: enabled

module Board::AutoPostponing
  extend ActiveSupport::Concern

  # @type self: singleton(Board) & singleton(Board::AutoPostponing)

  included do
    before_create :set_default_auto_postpone_period
  end

  private
    DEFAULT_AUTO_POSTPONE_PERIOD = 30.days

    def set_default_auto_postpone_period
      # @type self: Board & Board::AutoPostponing
      self.auto_postpone_period ||= DEFAULT_AUTO_POSTPONE_PERIOD unless attribute_present?(:auto_postpone_period)
    end
end
