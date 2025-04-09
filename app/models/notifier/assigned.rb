class Notifier::Assigned < Notifier
  private
    def recipients
      event.assignees.excluding(card.collection.access_only_users)
    end
end
