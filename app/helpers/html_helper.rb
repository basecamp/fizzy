module HtmlHelper
  def format_html(html)
    Loofah::HTML5::DocumentFragment.parse(html).scrub!(AutoLinkScrubber.new).to_html.html_safe
  end

  def card_html_title(card)
    return card.title if card.title.blank?

    ERB::Util.html_escape(card.title).gsub(/`([^`]+)`/, '<code>\1</code>').html_safe
  end
end
