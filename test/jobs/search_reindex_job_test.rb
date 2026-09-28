require "test_helper"

class SearchReindexJobTest < ActiveJob::TestCase
  test "reindexes cards and comments after their search records are nuked" do
    card = cards(:logo)
    comment = comments(:logo_1)

    card.reindex
    comment.reindex

    assert search_record_exists?(card.account_id, type: "Card", id: card.id)
    assert search_record_exists?(comment.account_id, type: "Comment", id: comment.id)

    clear_search_records

    assert_not search_record_exists?(card.account_id, type: "Card", id: card.id)
    assert_not search_record_exists?(comment.account_id, type: "Comment", id: comment.id)

    SearchReindexJob.perform_now

    assert search_record_exists?(card.account_id, type: "Card", id: card.id)
    assert search_record_exists?(comment.account_id, type: "Comment", id: comment.id)
  end

  test "skips records whose rich text exceeds rich_text_limit" do
    Current.account = accounts(:"37s")
    Current.session = Session.new(identity: identities(:david))

    big_card = boards(:writebook).cards.create!(
      creator: users(:david),
      title: "too big to index",
      status: :published,
      description: "x" * 5_000
    )
    small_card = boards(:writebook).cards.create!(
      creator: users(:david),
      title: "small enough to index",
      status: :published,
      description: "x" * 100
    )

    clear_search_records

    SearchReindexJob.perform_now(rich_text_limit: 1_000)

    assert_not search_record_exists?(big_card.account_id, type: "Card", id: big_card.id)
    assert search_record_exists?(small_card.account_id, type: "Card", id: small_card.id),
      "control: the job swallows every exception, so absence alone would also mean it indexed nothing"
  end

  test "does not index drafted cards or their comments" do
    Current.account = accounts(:"37s")
    Current.session = Session.new(identity: identities(:david))

    card = boards(:writebook).cards.create!(
      creator: users(:david),
      title: "will be drafted",
      status: :published
    )
    comment = card.comments.create!(creator: users(:david), body: "on a card that will be drafted")
    card.update!(status: :drafted)

    sibling = boards(:writebook).cards.create!(
      creator: users(:david),
      title: "stays published",
      status: :published
    )

    clear_search_records

    SearchReindexJob.perform_now

    assert_not search_record_exists?(card.account_id, type: "Card", id: card.id)
    assert_not search_record_exists?(comment.account_id, type: "Comment", id: comment.id)
    assert search_record_exists?(sibling.account_id, type: "Card", id: sibling.id),
      "control: the job swallows every exception, so absence alone would also mean it indexed nothing"
  end
end
