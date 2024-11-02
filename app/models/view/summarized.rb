module View::Summarized
  def summary
    "#{filter_summary} #{bucket_summary}".squish.upcase_first
  end

  def plain_summary
    summary.remove("<mark>").remove("</mark>")
  end

  private
    delegate :to_sentence, to: "ApplicationController.helpers", private: true

    def filter_summary
      unless bucket_default?
        [ index_summary, tag_summary, assignee_summary ].compact.to_sentence
      end
    end

    def index_summary
      "<mark>#{indexed_by.humanize}</mark>"
    end

    def tag_summary
      "tagged <mark>#{tags.map(&:hashtag).to_choice_sentence}</mark>" if tags.any?
    end

    def assignee_summary
      if assignees.any?
        "assigned to <mark>#{assignees.pluck(:name).to_choice_sentence}</mark>"
      elsif assignment.unassigned?
        "assigned to no one"
      end
    end

    def bucket_summary
      if bucket
        "in <mark>#{bucket.name}</mark>"
      else
        "in <mark>all projects</mark>"
      end
    end
end
