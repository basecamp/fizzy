class MagicLinkPreview < ActionMailer::Preview
  def magic_link
    identity = Identity.new email_address: "test@example.com"
    magic_link = MagicLink.new(identity: identity)
    magic_link.valid?

    MagicLinkMailer.sign_in_instructions(magic_link)
  end
end
