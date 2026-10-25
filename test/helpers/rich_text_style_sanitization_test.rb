require "test_helper"

class RichTextStyleSanitizationTest < ActionView::TestCase
  include ActionText::ContentHelper

  # Lexxy allows style on rich text, so Loofah's CSS scrubber is all that stands between a comment
  # and a page-covering overlay. Crass before 1.0.8 ran a bad url on past a ")" that follows an
  # escaped backslash, so the scrubber kept the declarations a browser reads after that ")" as part
  # of the allowed width (GHSA-pq4g-8rxf-4g29).
  test "a style attribute can't smuggle declarations past the css scrubber" do
    html = %{<div style='width: calc(url(a"\\\\)); position: fixed; top: 0; left: 0; /*)'>Your session has expired.</div>}
    div = Nokogiri::HTML5.fragment(sanitize_action_text_content(ActionText::Content.new(html))).at_css("div")

    assert_not_nil div, "the div itself is allowed"
    assert_no_match(/position|top|left/, div["style"].to_s, "only the scrubber's allowed properties may survive")
  end
end
