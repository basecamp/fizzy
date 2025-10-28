module User::Staff
  extend ActiveSupport::Concern

  def staff?
    if email_address = identity&.email_address
      email_address.ends_with?("@37signals.com") || email_address.ends_with?("@basecamp.com")
    end
  end
end
