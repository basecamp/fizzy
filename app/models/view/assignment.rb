module View::Assignment
  def assignment
    filters["assignment"].to_s.inquiry
  end

  def assignees
    @assignees ||= account.users.where id: assignment.split(",")
  end
end
