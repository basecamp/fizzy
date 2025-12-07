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
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(Rails.root.join("test", "fixtures", "files", "avatar.png")),
      filename: "avatar.png",
      content_type: "image/png"
    )
    @user.avatar.attach(blob)

    create_notification(@user)

    email = Notification::BundleMailer.notification(@bundle)

    assert_match /<img[^>]*class="avatar"[^>]*>/, email.html_part.body.to_s
    assert_match /<img[^>]*class="avatar"[^>]*src="[^"]*"/, email.html_part.body.to_s
    assert_match /alt="#{@user.name}"/, email.html_part.body.to_s
  end

  private
    def create_notification(user)
      Notification.create!(user: user, creator: user, source: events(:logo_published), created_at: 30.minutes.ago)
    end
end
