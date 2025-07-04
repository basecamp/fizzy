module Card::Mentions
  extend ActiveSupport::Concern

  included do
    include ::Mentions

    def mentionable?
      published?
    end
  end
end
