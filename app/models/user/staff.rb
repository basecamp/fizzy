module User::Staff
  extend ActiveSupport::Concern

  def staff?
    email_address.ends_with?("@37signals.com") || email_address.ends_with?("@basecamp.com")
  end
end
