require "test_helper"

class Link::FizzyUnfurlerTest < ActiveSupport::TestCase
  setup do
    @original_url_options = Rails.application.config.action_mailer.default_url_options
    Rails.application.config.action_mailer.default_url_options = { host: "fizzy.example.com", port: 3000 }
  end

  teardown do
    Rails.application.config.action_mailer.default_url_options = @original_url_options
  end

  test "unfurls?" do
    assert Link::FizzyUnfurler.unfurls?(URI.parse("https://fizzy.example.com:3000/123/cards/456"))
    assert Link::FizzyUnfurler.unfurls?(URI.parse("http://fizzy.example.com:3000/123/any/path"))

    assert_not Link::FizzyUnfurler.unfurls?(URI.parse("https://other.example.com:3000/123/cards/456"))
    assert_not Link::FizzyUnfurler.unfurls?(URI.parse("https://fizzy.example.com:3001/123/cards/456"))
  end

  test "unfurl" do
    user = users(:david)
    card = cards(:logo)
    tenant_id = ApplicationRecord.current_tenant
    url = "https://fizzy.example.com:3000/#{tenant_id}/cards/#{card.id}"

    metadata = Link::FizzyUnfurler.new(URI.parse(url), user: user).unfurl

    assert_equal card.title, metadata.title
    assert_equal url, metadata.canonical_url

    # Test different tenant
    different_tenant_url = "https://fizzy.example.com:3000/999/cards/#{card.id}"
    assert_nil Link::FizzyUnfurler.new(URI.parse(different_tenant_url), user: user).unfurl

    # Test non-existent card
    non_existent_url = "https://fizzy.example.com:3000/#{tenant_id}/cards/99999"
    assert_nil Link::FizzyUnfurler.new(URI.parse(non_existent_url), user: user).unfurl
  end
end
