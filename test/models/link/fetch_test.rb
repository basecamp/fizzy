require "test_helper"

class Link::FetchTest < ActiveSupport::TestCase
  test "http_url?" do
    fetch = Link::Fetch.new("https://example.com/page")
    assert fetch.http_url?

    non_http_fetch = Link::Fetch.new("ftp://example.com/file")
    assert_not non_http_fetch.http_url?
  end

  test "html_content?" do
    fetch = Link::Fetch.new("https://example.com/page")

    stub_request(:head, "https://example.com/page")
      .to_return(status: 200, headers: { "Content-Type" => "text/html; charset=utf-8" })

    assert fetch.html_content?

    stub_request(:head, "https://example.com/image")
      .to_return(status: 200, headers: { "Content-Type" => "image/jpeg" })

    image_fetch = Link::Fetch.new("https://example.com/image")
    assert_not image_fetch.html_content?
  end

  test "content_type" do
    fetch = Link::Fetch.new("https://example.com/page")

    stub_request(:head, "https://example.com/page")
      .to_return(status: 200, headers: { "Content-Type" => "text/html; charset=utf-8" })

    assert_equal "text/html; charset=utf-8", fetch.content_type

    stub_request(:head, "https://example.com/error")
      .to_return(status: 404)

    error_fetch = Link::Fetch.new("https://example.com/error")
    assert_raises(Link::Fetch::UnsuccesfulRequestError) do
      error_fetch.content_type
    end
  end

  test "content" do
    fetch = Link::Fetch.new("https://example.com/page")

    stub_request(:get, "https://example.com/page")
      .to_return(status: 200, body: "<html><title>Test</title></html>")

    content = fetch.content
    assert_includes content, "<title>Test</title>"

    stub_request(:get, "https://example.com/large")
      .to_return(status: 200, body: "x" * (Link::Fetch::MAX_BODY_SIZE + 1))

    large_fetch = Link::Fetch.new("https://example.com/large")
    assert_raises(Link::Fetch::BodyTooLargeError) do
      large_fetch.content
    end

    stub_request(:get, "https://example.com/error")
      .to_return(status: 404)

    error_fetch = Link::Fetch.new("https://example.com/error")
    assert_raises(Link::Fetch::UnsuccesfulRequestError) do
      error_fetch.content
    end
  end
end
