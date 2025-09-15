class Search::Result < ApplicationRecord
  belongs_to :creator, class_name: "User"
  belongs_to :card, foreign_key: :card_id, optional: true
  belongs_to :comment, foreign_key: :comment_id, optional: true

  def card_title
    escape_highlight card_title_in_database
  end

  def card_description
    escape_highlight card_description_in_database
  end

  def comment_body
    escape_highlight comment_body_in_database
  end

  def source
    comment_id.present? ? comment : card
  end

  def readonly?
    true
  end

  private
    def escape_highlight(html)
      if html
        CGI.escapeHTML(html)
          .gsub(CGI.escapeHTML(Search::HIGHLIGHT_OPENING_MARK), Search::HIGHLIGHT_OPENING_MARK.html_safe)
          .gsub(CGI.escapeHTML(Search::HIGHLIGHT_CLOSING_MARK), Search::HIGHLIGHT_CLOSING_MARK.html_safe)
          .html_safe
      else
        nil
      end
    end
end
