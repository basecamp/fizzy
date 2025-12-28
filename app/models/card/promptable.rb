# rbs_inline: enabled

module Card::Promptable
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Promptable)

  included do
    include Rails.application.routes.url_helpers
  end

  # parece não ser utilizado
  def to_prompt
    # @type self: Card & Card::Promptable
    <<~PROMPT
      BEGIN OF CARD #{id}

      **Title:** #{title.first(1000)}
      **Description:**

      #{description.to_plain_text.first(10_000)}

      #### Metadata

      * Id: #{id}
      * Created by: #{creator.name}}
      * Assigned to: #{assignees.map(&:name).join(", ")}
      * Column: #{column_prompt_label}
      * Created at: #{created_at}}
      * Board id: #{board_id}
      * Board name: #{board.name}
      * Number of comments: #{comments.count}
      * Path: #{card_path(self, script_name: account.slug)}

      END OF CARD #{id}
    PROMPT
  end

  private
    def column_prompt_label
      # @type self: Card & Card::Promptable
      if open?
        if postponed?
          "Not now"
        elsif triaged?
          "#{column&.name}"
        else
          "Maybe?"
        end
      else
        "Closed (by #{closed_by&.name} at #{closed_at})"
      end
    end
end
