module Filter::Assignments
  def assignments
    params["assignments"].to_s.inquiry
  end

  def assignees
    @assignees ||= account.users.where id: assignments.split(",")
  end
end
