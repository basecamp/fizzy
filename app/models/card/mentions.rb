module Card::Mentions
  extend ActiveSupport::Concern

  included do
    include ::Mentions

    def mentionable?
      published?
    end

    def should_check_mentions?
      was_just_published?
    end
  end
end
