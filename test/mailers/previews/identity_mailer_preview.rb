class IdentityMailerPreview < ActionMailer::Preview
  def email_change_confirmation
    ApplicationRecord.current_tenant = "897362094"

    identity = Identity.find_by(email_address: "david@37signals.com")
    membership = identity&.memberships&.find_by(tenant: ApplicationRecord.current_tenant)

    new_email_address = "david.new@example.com"
    token = membership.send(:generate_email_address_change_token, to: new_email_address)

    IdentityMailer.email_change_confirmation(
      email_address: new_email_address,
      token: token,
      membership: membership
    )
  end
end
