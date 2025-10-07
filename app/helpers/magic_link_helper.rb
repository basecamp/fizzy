module MagicLinkHelper
  def magic_link_code(magic_link)
    magic_link.code.scan(/.{3}/).join("-")
  end
end
