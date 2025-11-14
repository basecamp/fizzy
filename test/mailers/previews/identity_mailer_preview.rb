class IdentityMailerPreview < ActionMailer::Preview
  def email_change_confirmation
    new_email_address = "new.email@example.com"
    user = User.all.sample
    token = user.send(:generate_email_address_change_token, to: new_email_address)

    IdentityMailer.email_change_confirmation(
      email_address: new_email_address,
      token: token,
      user: user
    )
  end
end
