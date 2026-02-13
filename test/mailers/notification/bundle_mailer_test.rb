require "test_helper"

class Notification::BundleMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:david)
    @user.notifications.destroy_all

    @bundle = Notification::Bundle.create!(
      user: @user,
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now
    )
  end

  test "renders avatar with initials in span when avatar is not attached" do
    create_notification(@user)

    html = Nokogiri::HTML5(Notification::BundleMailer.notification(@bundle).html_part.body.to_s)

    avatar = html.at_css("span.avatar")
    assert avatar, "Expected a span.avatar element"
    assert_equal @user.initials, avatar.text.strip
    assert_match /background-color: #[A-F0-9]{6}/, avatar["style"]
  end

  test "renders avatar with external image URL when avatar is attached" do
    @user.avatar.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "avatar.png")),
      filename: "avatar.png",
      content_type: "image/png"
    )

    create_notification(@user)

    html = Nokogiri::HTML5(Notification::BundleMailer.notification(@bundle).html_part.body.to_s)

    avatar = html.at_css("img.avatar")
    assert avatar, "Expected an img.avatar element"
    assert avatar["src"].present?
    assert_equal @user.name, avatar["alt"]
  end

  test "groups notifications by board, sorted alphabetically" do
    private_board = boards(:private)
    private_card = Current.with(user: @user) do
      private_board.cards.create!(
        title: "Private card", creator: @user, status: :published, account: @user.account
      )
    end
    private_event = Event.create!(
      creator: @user, board: private_board, eventable: private_card,
      action: :card_published, account: @user.account
    )

    create_notification(@user, source: events(:logo_published))
    create_notification(@user, source: private_event)
    create_notification(@user, source: events(:layout_published))

    html = Nokogiri::HTML5(Notification::BundleMailer.notification(@bundle).html_part.body.to_s)

    board_headers = html.css(".notification__board")
    assert_equal 2, board_headers.size, "Should have exactly two board headers"
    assert_equal [ "Private board", "Writebook" ], board_headers.map(&:text)
  end

  test "board header links to the board" do
    create_notification(@user, source: events(:logo_published))

    html = Nokogiri::HTML5(Notification::BundleMailer.notification(@bundle).html_part.body.to_s)
    board = boards(:writebook)

    link = html.at_css(".notification__board a")
    assert_equal "Writebook", link.text
    assert_match %r{boards/#{board.id}}, link["href"]
  end

  test "shows multiple cards under same board header" do
    create_notification(@user, source: events(:logo_published))
    create_notification(@user, source: events(:layout_published))

    html = Nokogiri::HTML5(Notification::BundleMailer.notification(@bundle).html_part.body.to_s)

    assert_equal 1, html.css(".notification__board").size, "Same board should only have one header"

    card_titles = html.css(".card__title").map(&:text)
    assert_includes card_titles, "#1 The logo isn't big enough"
    assert_includes card_titles, "#2 Layout is broken"
  end

  test "renders inline code in card title" do
    cards(:logo).update_column :title, "Fix the `bug` in production"
    create_notification(@user, source: events(:logo_published))

    html = Nokogiri::HTML5(Notification::BundleMailer.notification(@bundle).html_part.body.to_s)

    title_link = html.at_css(".card__title")
    assert_equal "#1 Fix the <code>bug</code> in production", title_link.inner_html
  end

  test "skips notifications whose source event was deleted" do
    notification = create_notification(@user)
    notification.source.destroy

    email = Notification::BundleMailer.notification(@bundle)
    assert_not email.respond_to?(:deliver) && email.message.is_a?(Mail::Message),
      "Should not generate a real email when all notifications are stale"
  end

  private
    def create_notification(user, source: events(:logo_published))
      Notification.create!(user: user, creator: user, source: source, created_at: 30.minutes.ago)
    end
end
