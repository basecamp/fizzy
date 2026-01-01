# rbs_inline: enabled

class Access < ApplicationRecord
  belongs_to :account, default: -> { user.account }
  belongs_to :board, touch: true
  belongs_to :user, touch: true

  enum :involvement, %i[ access_only watching ].index_by(&:itself), default: :access_only

  scope :ordered_by_recently_accessed, -> { order(accessed_at: :desc) }

  after_destroy_commit :clean_inaccessible_data_later

  #: -> void
  def accessed
    touch :accessed_at unless recently_accessed?
  end

  private
    #: -> bool
    def recently_accessed?
      return false unless (accessed_at = accessed_at)

      accessed_at > 5.minutes.ago
    end

    #: -> void
    def clean_inaccessible_data_later
      Board::CleanInaccessibleDataJob.perform_later(user, board)
    end
end
