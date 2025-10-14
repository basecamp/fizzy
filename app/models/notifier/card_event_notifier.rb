class Notifier::CardEventNotifier < Notifier
  delegate :creator, to: :source
  delegate :collection, to: :card

  private
    def recipients
      case source.action
      when "card_assigned"
        source.assignees.excluding(creator)
      when "card_published"
        collection.watchers.without(creator, *card.mentionees)
      when "comment_created"
        card.watchers.without(creator, *source.eventable.mentionees)
      else
        collection.watchers.without(creator)
      end
    end

    def card
      source.eventable
    end
end
