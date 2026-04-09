class Event < ApplicationRecord
  include Notifiable, Particulars, Promptable

  belongs_to :account, default: -> { board.account }
  belongs_to :board
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  has_many :webhook_deliveries, class_name: "Webhook::Delivery", dependent: :delete_all

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }
  scope :for_creators, ->(ids) { where(creator_id: ids) if ids.present? }
  scope :for_boards, ->(ids) { where(board_id: ids) if ids.present? }
  scope :preloaded, -> {
    includes(:creator, :board, {
      eventable: [
        :creator, :goldness, :closure, :image_attachment,
        { rich_text_body: :embeds_attachments },
        { rich_text_description: :embeds_attachments },
        { card: [ :goldness, :closure, :image_attachment ] }
      ]
    })
  }

  after_create -> { eventable.event_was_created(self) }
  after_create_commit :dispatch_webhooks

  delegate :card, to: :eventable

  def action
    super.inquiry
  end

  def notifiable_target
    eventable
  end

  def description_for(user)
    Event::Description.new(self, user)
  end

  private
    def dispatch_webhooks
      Event::WebhookDispatchJob.perform_later(self)
    end
end
