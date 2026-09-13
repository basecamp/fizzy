require "test_helper"

class ActionTextContentAttachmentRenderByPathTest < ActiveSupport::TestCase
  test "renders the nested content" do
    assert_equal "<p>abc</p>", content_attachment.to_html.strip
  end

  test "the upstream implementation this patch replaces still needs replacing" do
    upstream = ActionText::Attachables::ContentAttachment.instance_method(:to_html).super_method

    assert_equal ActionText::Attachables::ContentAttachment, upstream&.owner,
      "Rails no longer defines ContentAttachment#to_html itself"

    error = assert_raises NoMethodError, removal_guidance do
      upstream.bind(content_attachment).call
    end

    assert_match(/include\?/, error.message, removal_guidance)
  end

  private
    def removal_guidance
      "Rails renders content attachments by partial path now (rails/rails#58755), so delete " \
        "lib/rails_ext/action_text_content_attachment_render_by_path.rb and this test"
    end

    def content_attachment
      html = %(<action-text-attachment content-type="text/html" content="&lt;p&gt;abc&lt;/p&gt;"></action-text-attachment>)
      ActionText::Content.new(html).attachables.sole
    end
end
