class UserMailerPreview < ActionMailer::Preview
  def email_change_confirmation
    user = User.active.sample
    Current.account = user.account

    UserMailer.email_change_confirmation(user: user, from: user.identity.email_address, to: "new.email@example.com")
  end
end
