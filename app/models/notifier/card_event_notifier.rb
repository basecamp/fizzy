class Notifier::CardEventNotifier < Notifier
  delegate :creator, to: :source
  delegate :board, to: :card

  private
    def recipients
      case source.action
      when "card_assigned"
        source.assignees.excluding(creator)
      when "card_published"
        board.watchers.without(creator, *card.scan_mentionees).including(*card.assignees).uniq
      when "comment_created"
        card.watchers.without(creator, *source.eventable.scan_mentionees)
      else
        board.watchers.without(creator)
      end
    end

    def card
      source.eventable
    end
end
