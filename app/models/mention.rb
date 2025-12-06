class Mention < ApplicationRecord
  include Notifiable

  belongs_to :account, default: -> { source.account }
  belongs_to :source, polymorphic: true
  belongs_to :mentioner, class_name: "User"
  belongs_to :mentionee, class_name: "User", inverse_of: :mentions

  after_create_commit :watch_source_by_mentionee
  after_create_commit :create_mentioned_event

  delegate :card, to: :source

  def self_mention?
    mentioner == mentionee
  end

  def notifiable_target
    source
  end

  private
    def watch_source_by_mentionee
      source.watch_by(mentionee)
    end

    def create_mentioned_event
      return if self_mention?
      
      card = source.card
      return unless card
      
      Event.create!(
        account: account,
        board: card.board,
        creator: mentioner,
        eventable: source,
        action: "user.mentioned",
        particulars: { mentioned_user_id: mentionee.id }
      )
    end
end

