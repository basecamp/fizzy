# rbs_inline: enabled

module Comment::Promptable
  extend ActiveSupport::Concern

  # @type self: singleton(Comment) & singleton(Comment::Promptable)

  included do
    include Rails.application.routes.url_helpers
  end

  def to_prompt
    # @type self: Comment & Comment::Promptable
    <<~PROMPT
        BEGIN OF COMMENT #{id}

        **Content:**

        #{body.to_plain_text.first(5000)}

        #### Metadata

        * Id: #{id}
        * Card id: #{card.number}
        * Card title: #{card.title}
        * Created by: #{creator.name}}
        * Created at: #{created_at}}
        * Path: #{card_path(card, anchor: ActionView::RecordIdentifier.dom_id(self), script_name: account.slug)}
        END OF COMMENT #{id}
      PROMPT
  end
end
