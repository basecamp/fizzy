module Filter::Summarized
  def summary
    [ index_summary, tag_summary, assignee_summary, assigner_summary, terms_summary ].compact.to_sentence + " #{bucket_summary}"
  end

  def plain_summary
    summary.remove(/<\/?mark>/)
  end

  private
    def index_summary
      indexed_by.humanize
    end

    def tag_summary
      if tags.any?
        "tagged #{tags.map(&:hashtag).to_choice_sentence}"
      end
    end

    def assignee_summary
      if assignees.any?
        "assigned to #{assignees.pluck(:name).to_choice_sentence}"
      elsif assignment_status.unassigned?
        "assigned to no one"
      end
    end

    def assigner_summary
      if assigners.any?
        "assigned by #{assigners.pluck(:name).to_choice_sentence}"
      end
    end

    def bucket_summary
      if buckets.any?
        "in #{buckets.pluck(:name).to_choice_sentence}"
      else
        "in all projects"
      end
    end

    def terms_summary
      if terms.any?
        "matching #{terms.map { |term| %Q("#{term}") }.to_sentence}"
      end
    end
end
