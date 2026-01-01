# rbs_inline: enabled

class Card < ApplicationRecord
  include Attachments, Prontable

  include Assignable
  include Broadcastable
  include Closeable
  include Colored
  include Entropic
  include Eventable
  include Exportable
  include Golden
  include Mentions
  include Multistep
  include Pinnable
  include Postponable
  include Readable
  include Searchable
  include Stallable
  include Statuses
  include Triageable
  include Watchable

  belongs_to :account, default: -> { board.account }

  belongs_to :board
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :comments, dependent: :destroy
  has_one_attached :image, dependent: :purge_later

  has_rich_text :description

  # @rbs!
  #   def description: () -> ActionText::RichText
  #   def description=: (ActionText::RichText) -> ActionText::RichText
  #
  #   class ::Card::ActiveRecord_Relation < ActiveRecord::Relation
  #     def connection: () -> untyped
  #   end

  validates :title, length: { maximum: 255 }
  validates :number, presence: true, uniqueness: { scope: :account_id }
  validates :board, presence: true

  before_save :set_default_title, if: :published?
  before_create :assign_number

  after_save   -> { board.touch }, if: -> { published? }

  after_touch  -> { board.touch }, if: :published?
  after_update :handle_board_change, if: :saved_change_to_board_id?

  scope :reverse_chronologically, -> { order created_at:     :desc, id: :desc }
  scope :chronologically,         -> { order created_at:     :asc,  id: :asc  }
  scope :latest,                  -> { order last_active_at: :desc, id: :desc }
  scope :with_users,              -> { preload(creator: [ :avatar_attachment, :account ], assignees: [ :avatar_attachment, :account ]) }
  scope :preloaded,               -> { with_users.preload(:column, :tags, :steps, :closure, :goldness, :activity_spike, :image_attachment, board: [ :entropy, :columns ], not_now: [ :user ]).with_rich_text_description_and_embeds }

  scope :indexed_by, ->(index) do
    case index
    when "stalled" then stalled
    when "postponing_soon" then postponing_soon
    when "closed" then closed
    when "not_now" then postponed.latest
    when "golden" then golden
    when "draft" then drafted
    else all
    end
  end

  scope :sorted_by, ->(sort) do
    case sort
    when "newest" then reverse_chronologically
    when "oldest" then chronologically
    when "latest" then latest
    else latest
    end
  end

  delegate :accessible_to?, to: :board

  #: -> Card
  def card
    self
  end

  #: -> String
  def to_param
    number.to_s
  end

  #: (Board) -> void
  def move_to(new_board)
    transaction do
      card.update!(board: new_board)
      card.events.update_all(board_id: new_board.id)
    end
  end

  #: -> bool
  def filled?
    title.present? || description.present?
  end

  #: -> String
  def title!
    title.presence || raise
  end

  private
    #: -> void
    def set_default_title
      self.title = "Untitled" if title.blank?
    end

    #: -> void
    def handle_board_change
      old_board = account.boards.find_by!(id: board_id_before_last_save)

      transaction do
        update! column: nil
        track_board_change_event(old_board.name)
        grant_access_to_assignees unless board.all_access?
      end

      remove_inaccessible_notifications_later
    end

    #: (String) -> void
    def track_board_change_event(old_board_name)
      track_event "board_changed", particulars: { old_board: old_board_name, new_board: board.name }
    end

    #: -> void
    def grant_access_to_assignees
      board.accesses.grant_to(assignees)
    end

    #: -> void
    def assign_number
      self.number ||= account.increment!(:cards_count).cards_count
    end
end
