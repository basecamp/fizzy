class MagicLinkPreview < ActionMailer::Preview
  def magic_link
    membership = Membership.new email_address: "test@example.com"
    magic_link = MagicLink.new(membership: membership)
    magic_link.valid?
    MagicLinkMailer.sign_in_instructions(magic_link)
  end
end
