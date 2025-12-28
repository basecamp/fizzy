# rbs_inline: enabled

class Notifier::CardEventNotifier < Notifier
  delegate :creator, to: :source
  delegate :board, to: :card

  # @rbs!
  #   def creator: () -> User
  #   def board: () -> Board

  private
    #: -> Array[::Notifier::_Recipient]
    def recipients
      case source.action
      when "card_assigned"
        source.assignees.excluding(creator)
      when "card_published"
        board.watchers.without(creator, *card.mentionees).including(*card.assignees).uniq
      when "comment_created"
        card.watchers.without(creator, *source.eventable.mentionees)
      else
        board.watchers.without(creator)
      end
    end

    #: (::Notifier::_Recipient) -> void
    def teste(recipient)
      recipient
    end

    #: -> void
    def teste2
      teste(Closure.new)
    end

    #: -> Card
    def card
      source.eventable
    end
end
