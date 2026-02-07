require "test_helper"

class Notification::BundleMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:david)

    @bundle = Notification::Bundle.create!(
      user: @user,
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now
    )
  end

  test "renders avatar with initials in span when avatar is not attached" do
    create_notification(@user)

    email = Notification::BundleMailer.notification(@bundle)

    assert_match /<span[^>]*class="avatar"[^>]*>/, email.html_part.body.to_s
    assert_match /#{@user.initials}/, email.html_part.body.to_s
    assert_match /style="background-color: #[A-F0-9]{6};?"/, email.html_part.body.to_s
  end

  test "renders avatar with external image URL when avatar is attached" do
    @user.avatar.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "avatar.png")),
      filename: "avatar.png",
      content_type: "image/png"
    )

    create_notification(@user)

    email = Notification::BundleMailer.notification(@bundle)

    assert_match /<img[^>]*class="avatar"[^>]*>/, email.html_part.body.to_s
    assert_match /<img[^>]*class="avatar"[^>]*src="[^"]*"/, email.html_part.body.to_s
    assert_match /alt="#{@user.name}"/, email.html_part.body.to_s
  end

  test "groups notifications by board" do
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

    html = Notification::BundleMailer.notification(@bundle).html_part.body.to_s

    board_headers = html.scan(/class="notification__board"/)
    assert_equal 2, board_headers.size, "Should have exactly two board headers"

    assert_match(/Writebook/, html)
    assert_match(/Private board/, html)
  end

  test "board header links to the board" do
    create_notification(@user, source: events(:logo_published))

    html = Notification::BundleMailer.notification(@bundle).html_part.body.to_s
    board = boards(:writebook)

    assert_match %r{<a[^>]*href="[^"]*boards/#{board.id}"[^>]*>Writebook</a>}, html
  end

  test "shows multiple cards under same board header" do
    create_notification(@user, source: events(:logo_published))
    create_notification(@user, source: events(:layout_published))

    html = Notification::BundleMailer.notification(@bundle).html_part.body.to_s

    board_header_count = html.scan(/class="notification__board"/).size
    assert_equal 1, board_header_count, "Same board should only have one header"

    assert_match(/The logo isn/, html)
    assert_match(/Layout is broken/, html)
  end

  private
    def create_notification(user, source: events(:logo_published))
      Notification.create!(user: user, creator: user, source: source, created_at: 30.minutes.ago)
    end
end
