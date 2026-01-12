require "test_helper"

class Storage::NoReuseTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    Current.account = @account  # Ensure blobs get correct account_id
    @board = @account.boards.create!(name: "Test", creator: users(:david))
  end

  # No-reuse validation
  # NOTE: For persisted records, ActiveStorage::Attached::One#attach raises
  # ActiveRecord::RecordNotSaved when validation fails.

  test "rejects attaching blob that already has tracked attachment" do
    blob = ActiveStorage::Blob.create_and_upload! \
      io: StringIO.new("x" * 1000),
      filename: "test.png",
      content_type: "image/png"

    # First attachment succeeds
    card1 = @board.cards.create!(title: "Card 1", creator: users(:david))
    card1.image.attach(blob)
    assert card1.image.attached?

    # Second attachment of same blob fails
    card2 = @board.cards.create!(title: "Card 2", creator: users(:david))
    assert_raises ActiveRecord::RecordNotSaved do
      card2.image.attach(blob)
    end

    # Verify only one attachment exists for this blob
    assert_equal 1, ActiveStorage::Attachment.where(blob_id: blob.id).count
  end

  test "allows reuse for ActionText embeds" do
    file = file_fixture("moon.jpg")
    blob = ActiveStorage::Blob.create_and_upload! \
      io: file.open,
      filename: "embed.jpg",
      content_type: "image/jpeg"

    embed_html = ActionText::Attachment.from_attachable(blob).to_html

    card1 = @board.cards.create!(title: "Card 1", creator: users(:david))
    card1.update!(description: "<p>#{embed_html}</p>")
    card1.reload

    card2 = @board.cards.create!(title: "Card 2", creator: users(:david))
    card2.update!(description: "<p>#{embed_html}</p>")
    card2.reload

    assert_equal 2, ActiveStorage::Attachment.where(
      record_type: "ActionText::RichText",
      name: "embeds",
      blob_id: blob.id
    ).count
  end

  test "purge_later does not purge blob when still attached elsewhere" do
    file = file_fixture("moon.jpg")
    blob = ActiveStorage::Blob.create_and_upload! \
      io: file.open,
      filename: "embed.jpg",
      content_type: "image/jpeg"

    embed_html = ActionText::Attachment.from_attachable(blob).to_html

    card1 = @board.cards.create!(title: "Card 1", creator: users(:david))
    card1.update!(description: "<p>#{embed_html}</p>")

    card2 = @board.cards.create!(title: "Card 2", creator: users(:david))
    card2.update!(description: "<p>#{embed_html}</p>")

    attachment = ActiveStorage::Attachment.find_by(
      record: card1.rich_text_description,
      name: "embeds",
      blob_id: blob.id
    )

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      attachment.purge_later
    end

    assert ActiveStorage::Blob.exists?(blob.id)
    assert_equal 1, ActiveStorage::Attachment.where(blob_id: blob.id).count
  end

  test "purge_later enqueues purge when last attachment is removed" do
    file = file_fixture("moon.jpg")
    blob = ActiveStorage::Blob.create_and_upload! \
      io: file.open,
      filename: "embed.jpg",
      content_type: "image/jpeg"

    embed_html = ActionText::Attachment.from_attachable(blob).to_html

    card = @board.cards.create!(title: "Card", creator: users(:david))
    card.update!(description: "<p>#{embed_html}</p>")
    card.reload

    attachment = ActiveStorage::Attachment.find_by(
      record: card.rich_text_description,
      name: "embeds",
      blob_id: blob.id
    )

    assert_enqueued_with job: ActiveStorage::PurgeJob, args: [ blob ] do
      attachment.purge_later
    end
  end

  test "rejects cross-account blob attachment" do
    other_account = Account.create!(name: "Other")
    other_board = other_account.boards.create!(name: "Other Board", creator: users(:david))

    # Blob created in @account context
    blob = ActiveStorage::Blob.create_and_upload! \
      io: StringIO.new("x" * 1000),
      filename: "test.png",
      content_type: "image/png"

    card = other_board.cards.create!(title: "Card", creator: users(:david))
    assert_raises ActiveRecord::RecordNotSaved do
      card.image.attach(blob)
    end

    # Verify attachment was not created (blob account doesn't match record account)
    assert_not card.reload.image.attached?
  end

  test "allows attaching blob to untracked record type" do
    file = file_fixture("moon.jpg")
    blob = ActiveStorage::Blob.create_and_upload! \
      io: file.open,
      filename: "avatar.jpg",
      content_type: "image/jpeg"

    # User avatar is not a tracked record type
    user = users(:david)
    user.avatar.attach(blob)

    # Should succeed - avatars are not storage-tracked
    assert user.avatar.attached?
  end

  test "allows multiple attachments of same blob to untracked record types" do
    file = file_fixture("moon.jpg")
    blob = ActiveStorage::Blob.create_and_upload! \
      io: file.open,
      filename: "avatar.jpg",
      content_type: "image/jpeg"

    # First attachment to untracked (avatar)
    user1 = users(:david)
    user1.avatar.attach(blob)
    assert user1.avatar.attached?

    # Second attachment to untracked (another avatar) should work
    # since no-reuse only checks tracked contexts
    user2 = users(:jz)
    user2.avatar.attach(blob)
    assert user2.avatar.attached?
  end
end
