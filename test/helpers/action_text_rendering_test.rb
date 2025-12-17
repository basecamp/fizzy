require "test_helper"

class ActionTextRenderingTest < ActionView::TestCase
  test "data-action attributes in user content are stripped" do
    malicious_html = <<~HTML
      <p>Click here: <a href="#" data-action="dangerous#action">malicious link</a></p>
    HTML

    content = ActionText::Content.new(malicious_html)
    rendered = content.to_s

    assert_no_match(/data-action/, rendered)
    assert_match(/<a href="#">malicious link<\/a>/, rendered)
  end
end
