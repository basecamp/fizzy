module Card::Mentions
  extend ActiveSupport::Concern

  included do
    include ::Mentions

    def mentionable?
      published?
    end

    def should_check_mentions?
      saved_change_to_status? && published?
    end
  end
end
