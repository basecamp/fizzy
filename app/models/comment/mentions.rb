module Comment::Mentions
  extend ActiveSupport::Concern

  included do
    include ::Mentions

    def mentionable?
      card.published?
    end
  end
end
