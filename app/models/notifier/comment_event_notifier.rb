# rbs_inline: enabled

class Notifier::CommentEventNotifier < Notifier
  delegate :creator, to: :source

  private
    def recipients
      card.watchers.without(creator, *source.eventable.mentionees)
    end

    # -> Card
    def card
      source.eventable.card
    end
end
