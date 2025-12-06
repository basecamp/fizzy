module ActionTextTestHelper
  def assert_action_text(expected_html, content)
    assert_equal_html <<~HTML, content.to_s
      <div class="action-text-content">#{expected_html}</action-text-content>
    HTML
  end

  def assert_equal_html(expected, actual)
    assert_equal normalize_html(expected), normalize_html(actual)
  end

  def normalize_html(html)
    Nokogiri::HTML.fragment(html).tap do |fragment|
      fragment.traverse do |node|
        if node.text?
          node.content = node.text.squish
        end
      end
    end.to_html.strip
  end

  def attachment_html(blob)
    ActionText::Attachment.from_attachable(blob).to_html
  end
end
