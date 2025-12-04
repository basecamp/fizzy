require "test_helper"

class Link::MetadataTest < ActiveSupport::TestCase
  test "initialize" do
    metadata = Link::Metadata.new(
      title: "<script>alert('xss')</script>Safe Title<b>Bold</b>",
      description: "<p>Paragraph with <a href='#'>link</a></p>",
      canonical_url: "https://example.com/page",
      image_url: "/images/photo.jpg"
    )

    assert_equal "alert('xss')Safe TitleBold", metadata.title
    assert_equal "Paragraph with link", metadata.description
    assert_equal "https://example.com/page", metadata.canonical_url
    assert_equal "https://example.com/images/photo.jpg", metadata.image_url

    assert_equal "<script>alert('xss')</script>Safe Title<b>Bold</b>", metadata.unsafe_title
    assert_equal "<p>Paragraph with <a href='#'>link</a></p>", metadata.unsafe_description
    assert_equal "https://example.com/page", metadata.unsafe_canonical_url
    assert_equal "/images/photo.jpg", metadata.unsafe_image_url

    invalid_metadata = Link::Metadata.new(
      canonical_url: "javascript:alert('xss')",
      image_url: "ftp://example.com/image.jpg"
    )

    assert_nil invalid_metadata.canonical_url
    assert_nil invalid_metadata.image_url
  end
end
