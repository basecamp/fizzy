require "test_helper"

class Account::IncineratableTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")
    @user = users(:david)
  end

  test "incinerate destroys account" do
    assert_difference -> { Account.count }, -1 do
      @account.incinerate
    end

    assert_not Account.exists?(@account.id)
  end

  test "due_for_incineration finds old cancellations" do
    @account.cancel(initiated_by: @user)

    @account.cancellation.update!(created_at: 31.days.ago)
    assert_equal [ @account ], Account.due_for_incineration

    @account.cancellation.update!(created_at: 29.days.ago)
    assert Account.due_for_incineration.empty?
  end

  test "incinerate destroys all associated records" do
    account = accounts(:initech)
    board = boards(:miltons_wish_list)
    card = cards(:radio)

    Current.account = account
    Current.session = Session.new(identity: identities(:mike))

    user = users(:mike)
    user.create_settings!(bundle_email_frequency: :never)

    # Direct on Account
    tag = Tag.create!(title: "urgent")
    column = Column.create!(board: board, name: "Test", position: 0)
    export = Account::Export.create!(account: account, user: user)
    search_query = Search::Query.create!(user: user, terms: "test search")
    storage_entry = Storage::Entry.create!(account: account, delta: 100, operation: "attach")

    # Via Board
    publication = Board::Publication.create!(board: board)
    webhook = Webhook.create!(board: board, name: "Test", url: "https://example.com/webhook")
    event = Event.create!(board: board, creator: user, eventable: card, action: "card_published")

    # Via Webhook
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)
    # DelinquencyTracker is auto-created with Webhook

    # Via Card
    comment = card.comments.create!(body: "Test comment")
    step = Step.create!(card: card, content: "Test step")
    assignment = Assignment.create!(card: card, assignee: user, assigner: user)
    tagging = Tagging.create!(card: card, tag: tag)
    watch = Watch.create!(card: card, user: user)
    pin = Pin.create!(card: card, user: user)
    reaction = Reaction.create!(reactable: card, content: "thumbs_up")
    mention = Mention.create!(source: card, mentioner: user, mentionee: user)
    closure = Closure.create!(card: cards(:paycheck), user: user)
    goldness = Card::Goldness.create!(card: card)
    not_now = Card::NotNow.create!(card: cards(:unfinished_thoughts), user: user)
    activity_spike = Card::ActivitySpike.create!(card: card)

    # Via User
    notification = Notification.create!(user: user, source: event, creator: user)
    notification_bundle = Notification::Bundle.create!(user: user, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
    filter = Filter.create!(creator: user, fields: { indexed_by: :all, sorted_by: :newest }.to_json, params_digest: SecureRandom.hex)

    # ActiveStorage (attach image to card)
    card.image.attach(io: StringIO.new("fake image"), filename: "test.png", content_type: "image/png")

    account_id = account.id
    user_ids = User.where(account_id: account_id).pluck(:id)

    # Confirm records exist before destroy
    assert User.where(account_id: account_id).exists?
    assert Board.where(account_id: account_id).exists?
    assert Card.where(account_id: account_id).exists?
    assert Tag.where(account_id: account_id).exists?
    assert Column.where(account_id: account_id).exists?
    assert Webhook.where(account_id: account_id).exists?
    assert Access.where(account_id: account_id).exists?
    assert Entropy.where(account_id: account_id).exists?
    assert Account::JoinCode.where(account_id: account_id).exists?
    assert Account::Export.where(account_id: account_id).exists?
    assert Search::Query.where(account_id: account_id).exists?
    assert Storage::Entry.where(account_id: account_id).exists?
    assert Board::Publication.where(account_id: account_id).exists?
    assert Event.where(account_id: account_id).exists?
    assert Webhook::Delivery.where(account_id: account_id).exists?
    assert Webhook::DelinquencyTracker.where(account_id: account_id).exists?
    assert Comment.where(account_id: account_id).exists?
    assert Step.where(account_id: account_id).exists?
    assert Assignment.where(account_id: account_id).exists?
    assert Tagging.where(account_id: account_id).exists?
    assert Watch.where(account_id: account_id).exists?
    assert Pin.where(account_id: account_id).exists?
    assert Reaction.where(account_id: account_id).exists?
    assert Mention.where(account_id: account_id).exists?
    assert Closure.where(account_id: account_id).exists?
    assert Card::Goldness.where(account_id: account_id).exists?
    assert Card::NotNow.where(account_id: account_id).exists?
    assert Card::ActivitySpike.where(account_id: account_id).exists?
    assert Notification.where(account_id: account_id).exists?
    assert Notification::Bundle.where(account_id: account_id).exists?
    assert Filter.where(account_id: account_id).exists?
    assert User::Settings.where(user_id: user.id).exists?
    assert ActiveStorage::Attachment.where(account_id: account_id).exists?
    assert ActiveStorage::Blob.where(account_id: account_id).exists?
    assert ActionText::RichText.where(account_id: account_id).exists?

    # Flush jobs enqueued during setup (Turbo broadcasts, etc.) while records still exist
    perform_enqueued_jobs

    account.incinerate
    perform_enqueued_jobs

    # Confirm account is gone
    assert_not Account.exists?(account_id)

    # Direct associations
    assert_empty User.where(account_id: account_id)
    assert_empty Board.where(account_id: account_id)
    assert_empty Card.where(account_id: account_id)
    assert_empty Webhook.where(account_id: account_id)
    assert_empty Tag.where(account_id: account_id)
    assert_empty Column.where(account_id: account_id)
    assert_empty Entropy.where(account_id: account_id)
    assert_empty Account::JoinCode.where(account_id: account_id)
    assert_empty Account::Export.where(account_id: account_id)
    assert_empty Account::Import.where(account_id: account_id)
    assert_empty Search::Query.where(account_id: account_id)

    # Via Board
    assert_empty Board::Publication.where(account_id: account_id)
    assert_empty Access.where(account_id: account_id)
    assert_empty Event.where(account_id: account_id)

    # Via Webhook
    assert_empty Webhook::Delivery.where(account_id: account_id)
    assert_empty Webhook::DelinquencyTracker.where(account_id: account_id)

    # Via Card
    assert_empty Comment.where(account_id: account_id)
    assert_empty Step.where(account_id: account_id)
    assert_empty Assignment.where(account_id: account_id)
    assert_empty Tagging.where(account_id: account_id)
    assert_empty Watch.where(account_id: account_id)
    assert_empty Pin.where(account_id: account_id)
    assert_empty Reaction.where(account_id: account_id)
    assert_empty Mention.where(account_id: account_id)
    assert_empty Closure.where(account_id: account_id)
    assert_empty Card::Goldness.where(account_id: account_id)
    assert_empty Card::NotNow.where(account_id: account_id)
    assert_empty Card::ActivitySpike.where(account_id: account_id)

    # Via User
    assert_empty Notification.where(account_id: account_id)
    assert_empty Notification::Bundle.where(account_id: account_id)
    assert_empty Filter.where(account_id: account_id)
    assert_empty User::Settings.where(user_id: user_ids)

    # Storage
    assert_empty Storage::Entry.where(account_id: account_id)
    assert_empty Storage::Total.where(owner_type: "Account", owner_id: account_id)

    # ActiveStorage / ActionText
    assert_empty ActiveStorage::Attachment.where(account_id: account_id)
    assert_empty ActiveStorage::Blob.where(account_id: account_id)
    assert_empty ActionText::RichText.where(account_id: account_id)

    # Search records (sharded)
    assert_empty Search::Record.for(account_id).where(account_id: account_id)
  end

  test "incinerating an account clears its own search records but preserves others on the same shard" do
    doomed = accounts(:initech)
    shard = Search::Record.for(doomed.id)

    doomed_card = cards(:radio)
    doomed_record = shard.create!(
      account_id: doomed_card.account_id,
      searchable_type: "Card",
      searchable_id: doomed_card.id,
      card_id: doomed_card.id,
      board_id: doomed_card.board_id,
      title: "doomed",
      content: "should be destroyed",
      created_at: Time.current
    )

    # Simulate a shard collision: plant a record belonging to a different
    # account directly on doomed's shard, as would happen in production when
    # two accounts' UUIDs hash to the same shard.
    foreign_card = cards(:logo)
    foreign_record = shard.create!(
      account_id: foreign_card.account_id,
      searchable_type: "Card",
      searchable_id: foreign_card.id,
      card_id: foreign_card.id,
      board_id: foreign_card.board_id,
      title: "foreign",
      content: "should survive",
      created_at: Time.current
    )

    Current.account = doomed
    Current.session = Session.new(identity: identities(:mike))
    doomed.incinerate

    assert_not shard.exists?(id: doomed_record.id),
      "the incinerated account's search record should be destroyed"
    assert shard.exists?(id: foreign_record.id),
      "another account's search record on the same shard should survive"
  end
end
