require "test_helper"

class Event::DescriptionTest < ActiveSupport::TestCase
  test "generates html description for card published event" do
    description = events(:logo_published).description_for(users(:david))

    assert_includes description.to_html, "added"
    assert_includes description.to_html, "logo"
  end

  test "generates plain text description for card published event" do
    description = events(:logo_published).description_for(users(:david))

    assert_includes description.to_plain_text, "David added"
    assert_includes description.to_plain_text, "logo"
  end

  test "generates description for comment event" do
    description = events(:layout_commented).description_for(users(:jz))

    assert_includes description.to_plain_text, "David commented on"
  end

  test "uses always the name even when the event creator is the current user" do
    description = events(:logo_published).description_for(users(:david))

    assert_includes description.to_plain_text, "David added"
  end

  test "uses creator name when event creator is not the current user" do
    description = events(:logo_published).description_for(users(:jz))

    assert_includes description.to_plain_text, "David added"
  end

  test "escapes html in card titles in plain text description" do
    card = cards(:logo)
    card.update_column(:title, "<script>alert('xss')</script>")

    description = events(:logo_published).description_for(users(:david))

    assert_includes description.to_plain_text, "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    assert_not_includes description.to_plain_text, "<script>"
  end
end
