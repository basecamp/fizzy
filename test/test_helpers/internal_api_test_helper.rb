module InternalApiTestHelper
  def self.setup_stubs
    WebMock.stub_request(:post, "http://example.com/identities/send_magic_link")
      .to_return do |request|
        body = JSON.parse(request.body)
        magic_link = Identity.find_by(email_address: body["email_address"])&.send_magic_link
        { status: 200, body: { code: magic_link&.code }.to_json, headers: { "Content-Type" => "application/json" } }
      end

    WebMock.stub_request(:post, "http://example.com/identities/link")
      .to_return do |request|
        body = JSON.parse(request.body)
        Identity.link(email_address: body["email_address"], to: body["to"])
        { status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" } }
      end

    WebMock.stub_request(:post, "http://example.com/identities/unlink")
      .to_return do |request|
        body = JSON.parse(request.body)
        Identity.unlink(email_address: body["email_address"], from: body["from"])
        { status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" } }
      end

    WebMock.stub_request(:post, "http://example.com/identities/change_email_address")
      .to_return do |request|
        body = JSON.parse(request.body)
        Membership.change_email_address(from: body["from"], to: body["to"], tenant: body["tenant"])
        { status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" } }
      end
  end
end
