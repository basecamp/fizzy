module Card::Promptable
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  def to_prompt
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
      if open?
        if postponed?
          I18n.t("columns.not_now")
        elsif triaged?
          "#{column&.name}"
        else
          I18n.t("columns.maybe")
        end
      else
        "Closed (by #{closed_by&.name} at #{closed_at})"
      end
    end
end
