module HtmlHelper
  def format_html(html)
    Loofah::HTML5::DocumentFragment.parse(html).scrub!(AutoLinkScrubber.new).to_html.html_safe
  end
end
