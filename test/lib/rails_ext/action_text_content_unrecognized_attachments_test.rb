require "test_helper"

class ActionTextContentUnrecognizedAttachmentsTest < ActiveSupport::TestCase
  test "keeps attachments without recognized attributes" do
    assert_kind_of ActionText::Attachables::MissingAttachable, content.attachments.sole.attachable
  end

  test "renders attachments without recognized attributes" do
    assert_match "<p>Hello</p><action-text-attachment>☒</action-text-attachment>", content.to_rendered_html_with_layout
  end

  test "the upstream implementation this patch replaces still needs replacing" do
    upstream = ActionText::Content.instance_method(:attachment_for_node).super_method

    assert_equal ActionText::Content, upstream&.owner,
      "Rails no longer defines Content#attachment_for_node itself"

    assert_nil upstream.bind(content).call(content.send(:attachment_nodes).sole),
      "Rails keeps attachments without recognized attributes now, so delete " \
        "lib/rails_ext/action_text_content_unrecognized_attachments.rb and this test"
  end

  private
    def content
      ActionText::Content.new(%(<p>Hello</p><action-text-attachment gid="gid://fizzy/Card/abc"></action-text-attachment>))
    end
end
