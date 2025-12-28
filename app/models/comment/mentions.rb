# rbs_inline: enabled

module Comment::Mentions
  extend ActiveSupport::Concern

  included do
    include ::Mentions

    def mentionable?
      # @type self: Comment & Comment::Mentions
      card.published?
    end
  end
end
