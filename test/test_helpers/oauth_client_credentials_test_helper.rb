module OauthClientCredentialsTestHelper
  # RFC 6749 §2.3.1 / Appendix B: each half is form-urlencoded, then joined
  # with a colon and Basic-encoded.
  def basic(client_id, secret)
    encoded = [ client_id, secret ].map { |part| URI.encode_www_form_component(part) }.join(":")
    { "Authorization" => "Basic #{Base64.strict_encode64(encoded)}" }
  end

  # RFC 6749 §5.2: invalid_client is a 401, and it names the Basic scheme
  # only to a client that tried the Authorization header.
  def assert_client_authentication_failed(message = nil, challenged: true)
    assert_response :unauthorized, message
    assert_equal "invalid_client", response.parsed_body["error"], message

    if challenged
      assert_equal %(Basic realm="http://www.example.com/"), response.headers["WWW-Authenticate"], message
    else
      assert_nil response.headers["WWW-Authenticate"], message
    end
  end
end
