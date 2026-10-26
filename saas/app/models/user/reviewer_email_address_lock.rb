# The directory reviewer's users keep the reviewer's email address. An email
# change moves a user to another identity, so a holder of the reviewer code
# could otherwise move the reviewer's membership to an address they control,
# where rotating the code and `saas:reviewer_sign_in:sign_out` can't reach it.
# The reviewer is a comped internal identity, so nobody needs to change it.
module User::ReviewerEmailAddressLock
  def send_email_address_change_confirmation(new_email_address)
    super unless email_address_locked?
  end

  def change_email_address(new_email_address)
    if email_address_locked?
      false
    else
      super
    end
  end

  def email_address_locked?
    Identity::ReviewerSignIn.reviewer?(identity)
  end
end
