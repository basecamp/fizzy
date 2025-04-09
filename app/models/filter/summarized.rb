module Filter::Summarized
  def summary
    [ index_summary, tag_summary, assignee_summary, creator_summary, stage_summary, terms_summary ].compact.to_sentence + " #{collection_summary}"
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

    def stage_summary
      if stages.any?
        "staged in #{stages.pluck(:name).to_choice_sentence}"
      end
    end

    def collection_summary
      if collections.any?
        "in #{collections.pluck(:name).to_choice_sentence}"
      end
    end

    def terms_summary
      if terms.any?
        "matching #{terms.map { |term| %Q("#{term}") }.to_sentence}"
      end
    end

    def creator_summary
      if creators.any?
        "added by #{creators.pluck(:name).to_choice_sentence}"
      end
    end
end
