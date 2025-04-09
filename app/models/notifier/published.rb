class Notifier::Published < Notifier
  private
    def recipients
      card.watchers_and_subscribers(include_only_watching: true).without(creator)
    end
end
