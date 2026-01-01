# rbs_inline: enabled

class Event < ApplicationRecord
  include Notifiable
  include Particulars
  include Promptable

  belongs_to :account, default: -> { board.account }
  belongs_to :board
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  has_many :webhook_deliveries, class_name: "Webhook::Delivery", dependent: :delete_all

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :preloaded, -> {
    includes(:creator, :board, {
      eventable: [
        :goldness, :closure, :image_attachment,
        { rich_text_body: :embeds_attachments },
        { rich_text_description: :embeds_attachments },
        { card: [ :goldness, :closure, :image_attachment ] }
      ]
    })
  }

  after_create -> { eventable.event_was_created(self) }
  after_create_commit :dispatch_webhooks

  delegate :card, to: :eventable

  #: -> ActiveSupport::StringInquirer
  def action
    super.inquiry
  end

  def notifiable_target
    eventable
  end

  #: (User) -> Event::Description
  def description_for(user)
    Event::Description.new(self, user)
  end

  private
    #: -> void
    def dispatch_webhooks
      Event::WebhookDispatchJob.perform_later(self)
    end
end
