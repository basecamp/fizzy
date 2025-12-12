require "test_helper"

class User::AvatarTest < ActiveSupport::TestCase
  test "avatar_thumbnail returns variant for variable images" do
    users(:david).avatar.attach(io: File.open(file_fixture("moon.jpg")), filename: "moon.jpg", content_type: "image/jpeg")

    assert users(:david).avatar.variable?
    assert_equal users(:david).avatar.variant(:thumb).blob, users(:david).avatar_thumbnail.blob
  end

  test "avatar_thumbnail returns original blob for non-variable images" do
    users(:david).avatar.attach(io: File.open(file_fixture("avatar.svg")), filename: "avatar.svg", content_type: "image/svg+xml")

    assert_not users(:david).avatar.variable?
    assert_equal users(:david).avatar.blob, users(:david).avatar_thumbnail.blob
  end

  test "allows valid image content types" do
    users(:david).avatar.attach(io: File.open(file_fixture("moon.jpg")), filename: "test.jpg", content_type: "image/jpeg")

    assert users(:david).valid?
  end

  test "rejects SVG uploads" do
    users(:david).avatar.attach(io: File.open(file_fixture("avatar.svg")), filename: "avatar.svg")

    assert_not users(:david).valid?
    assert_includes users(:david).errors[:avatar], "must be a JPEG, PNG, GIF, or WebP image"
  end

  test "thumb variant is processed immediately on attachment" do
    users(:david).avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")

    assert users(:david).avatar.variant(:thumb).processed?
  end
end
