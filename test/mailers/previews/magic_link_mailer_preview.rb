class MagicLinkMailerPreview < ActionMailer::Preview
  def magic_link
    identity = Identity.all.sample
    magic_link = MagicLink.new(identity: identity)
    magic_link.valid?

    MagicLinkMailer.sign_in_instructions(magic_link)
  end
end
