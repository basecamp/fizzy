module Filter::Titled
  def title
    [ index_summary, tag_summary, assignee_summary ].compact.to_sentence + " #{bucket_summary}"
  end

  def plain_title
    title.remove(/<\/?mark>/)
  end

  private
    def index_summary
      "<mark>#{indexed_by.humanize}</mark>"
    end

    def tag_summary
      if tags.exists?
        "tagged <mark>#{tags.map(&:hashtag).to_choice_sentence}</mark>"
      end
    end

    def assignee_summary
      if assignees.exists?
        "assigned to <mark>#{assignees.pluck(:name).to_choice_sentence}</mark>"
      elsif assignments.unassigned?
        "assigned to no one"
      end
    end

    def bucket_summary
      if buckets.exists?
        "in <mark>#{buckets.map(&:title).to_choice_sentence}</mark>"
      else
        "in <mark>all projects</mark>"
      end
    end
end
