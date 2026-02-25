require "test_helper"

class Event::DescriptionTest < ActiveSupport::TestCase
  test "html description is html safe" do
    description = events(:logo_published).description_for(users(:david))

    assert_predicate description.to_html, :html_safe?
  end

  test "generates html description for card published event" do
    description = events(:logo_published).description_for(users(:david))

    assert_includes description.to_html, "added"
    assert_includes description.to_html, "logo"
  end

  test "plain text description is html safe" do
    description = events(:logo_published).description_for(users(:david))

    assert_predicate description.to_plain_text, :html_safe?
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

  test "to_html escapes assignee names" do
    users(:jz).update_column(:name, "Tom & Jerry")
    description = events(:logo_assignment_jz).description_for(users(:david))

    assert_includes description.to_html, "Tom &amp; Jerry"
    assert_not_includes description.to_html, "Tom & Jerry"
  end

  test "to_plain_text escapes assignee names" do
    users(:jz).update_column(:name, "Tom & Jerry")
    description = events(:logo_assignment_jz).description_for(users(:david))

    assert_includes description.to_plain_text, "Tom &amp; Jerry"
    assert_not_includes description.to_plain_text, "Tom &amp;amp; Jerry"
  end

  test "to_html escapes unassigned names" do
    users(:jz).update_column(:name, "Tom & Jerry")
    event = events(:logo_assignment_jz)
    event.update_column(:action, "card_unassigned")
    description = event.description_for(users(:david))

    assert_includes description.to_html, "Tom &amp; Jerry"
    assert_not_includes description.to_html, "Tom & Jerry"
  end

  test "to_plain_text escapes unassigned names" do
    users(:jz).update_column(:name, "Tom & Jerry")
    event = events(:logo_assignment_jz)
    event.update_column(:action, "card_unassigned")
    description = event.description_for(users(:david))

    assert_includes description.to_plain_text, "Tom &amp; Jerry"
    assert_not_includes description.to_plain_text, "Tom &amp;amp; Jerry"
  end

  test "to_html escapes old title in renamed description" do
    event = events(:logo_published)
    event.update_columns(action: "card_title_changed", particulars: { "particulars" => { "old_title" => "Tom & Jerry" } })
    description = event.description_for(users(:david))

    assert_includes description.to_html, "Tom &amp; Jerry"
    assert_not_includes description.to_html, "Tom & Jerry"
  end

  test "to_plain_text escapes old title in renamed description" do
    event = events(:logo_published)
    event.update_columns(action: "card_title_changed", particulars: { "particulars" => { "old_title" => "Tom & Jerry" } })
    description = event.description_for(users(:david))

    assert_includes description.to_plain_text, "Tom &amp; Jerry"
    assert_not_includes description.to_plain_text, "Tom &amp;amp; Jerry"
  end

  test "to_html escapes board name in moved description" do
    event = events(:logo_published)
    event.update_columns(action: "card_board_changed", particulars: { "particulars" => { "new_board" => "Tom & Jerry" } })
    description = event.description_for(users(:david))

    assert_includes description.to_html, "Tom &amp; Jerry"
    assert_not_includes description.to_html, "Tom & Jerry"
  end

  test "to_plain_text escapes board name in moved description" do
    event = events(:logo_published)
    event.update_columns(action: "card_board_changed", particulars: { "particulars" => { "new_board" => "Tom & Jerry" } })
    description = event.description_for(users(:david))

    assert_includes description.to_plain_text, "Tom &amp; Jerry"
    assert_not_includes description.to_plain_text, "Tom &amp;amp; Jerry"
  end

  test "to_html escapes column name in triaged description" do
    event = events(:logo_published)
    event.update_columns(action: "card_triaged", particulars: { "particulars" => { "column" => "Tom & Jerry" } })
    description = event.description_for(users(:david))

    assert_includes description.to_html, "Tom &amp; Jerry"
    assert_not_includes description.to_html, "Tom & Jerry"
  end

  test "to_plain_text escapes column name in triaged description" do
    event = events(:logo_published)
    event.update_columns(action: "card_triaged", particulars: { "particulars" => { "column" => "Tom & Jerry" } })
    description = event.description_for(users(:david))

    assert_includes description.to_plain_text, "Tom &amp; Jerry"
    assert_not_includes description.to_plain_text, "Tom &amp;amp; Jerry"
  end

  test "escapes html in card titles in plain text description" do
    card = cards(:logo)
    card.update_column(:title, "<script>alert('xss')</script>")

    description = events(:logo_published).description_for(users(:david))

    assert_includes description.to_plain_text, "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    assert_not_includes description.to_plain_text, "<script>"
  end
end
