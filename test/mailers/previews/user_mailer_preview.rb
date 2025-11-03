class UserMailerPreview < ActionMailer::Preview
  def email_change_confirmation
    ApplicationRecord.current_tenant = "897362094"
    user = User.find_by(email_address: "david@37signals.com") || User.new(
      name: "David",
      email_address: "david@37signals.com"
    )

    new_email_address = "david.new@example.com"
    token = user.generate_email_address_change_token(to: new_email_address)

    UserMailer.email_change_confirmation(
      user: user,
      email_address: new_email_address,
      token: token
    )
  end
end
