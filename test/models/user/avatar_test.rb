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

  test "rejects images that are too wide" do
    users(:david).avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    users(:david).avatar.blob.update!(metadata: { analyzed: true, width: 5000, height: 100 })

    assert_not users(:david).valid?
    assert_includes users(:david).errors[:avatar], "width must be less than #{User::Avatar::MAX_AVATAR_DIMENSIONS[:width]}px"
  end

  test "rejects images that are too tall" do
    users(:david).avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    users(:david).avatar.blob.update!(metadata: { analyzed: true, width: 100, height: 5000 })

    assert_not users(:david).valid?
    assert_includes users(:david).errors[:avatar], "height must be less than #{User::Avatar::MAX_AVATAR_DIMENSIONS[:height]}px"
  end

  test "accepts images within dimension limits" do
    users(:david).avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    users(:david).avatar.blob.update!(metadata: { analyzed: true, width: 4096, height: 4096 })

    assert users(:david).valid?
  end
end
