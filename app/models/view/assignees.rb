module View::Assignees
  extend ActiveSupport::Concern

  def assignment
    filters[:assignment].to_s.inquiry
  end

  def assignees
    @assignees ||= unless assignment.unassigned? || assignment.assigned?
      account.users.where id: assignment.split(",")
    end
  end
end
