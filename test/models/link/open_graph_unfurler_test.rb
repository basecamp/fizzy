require "test_helper"

class Link::OpenGraphUnfurlerTest < ActiveSupport::TestCase
  test "unfurls?" do
    assert Link::OpenGraphUnfurler.unfurls?(URI.parse("https://example.com/page"))
    assert Link::OpenGraphUnfurler.unfurls?(URI.parse("https://any-site.com/path"))
    assert_not Link::OpenGraphUnfurler.unfurls?(URI.parse("ftp://any-site.com/path"))
  end

  test "unfurl" do
    url = "https://example.com/page"

    stub_request(:head, url)
      .to_return(status: 200, headers: { "Content-Type" => "text/html" })

    stub_request(:get, url)
      .to_return(status: 200, body: <<~HTML)
        <html>
          <head>
            <title>Page Title</title>
            <meta property="og:title" content="OG Title">
            <meta property="og:description" content="OG Description">
            <meta property="og:url" content="https://example.com/canonical">
            <meta property="og:image" content="https://example.com/image.jpg">
          </head>
        </html>
      HTML

    metadata = Link::OpenGraphUnfurler.new(URI.parse(url)).unfurl

    assert_equal "OG Title", metadata.title
    assert_equal "OG Description", metadata.description
    assert_equal "https://example.com/canonical", metadata.canonical_url
    assert_equal "https://example.com/image.jpg", metadata.image_url

    stub_request(:head, "https://example.com/non-html")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" })

    assert_nil Link::OpenGraphUnfurler.new(URI.parse("https://example.com/non-html")).unfurl
    assert_nil Link::OpenGraphUnfurler.new(URI.parse("ftp://example.com/file")).unfurl
  end
end
