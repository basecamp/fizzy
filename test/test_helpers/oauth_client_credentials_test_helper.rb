module OauthClientCredentialsTestHelper
  # RFC 6749 §2.3.1 / Appendix B: each half is form-urlencoded, then joined
  # with a colon and Basic-encoded.
  def basic(client_id, secret)
    encoded = [ client_id, secret ].map { |part| URI.encode_www_form_component(part) }.join(":")
    { "Authorization" => "Basic #{Base64.strict_encode64(encoded)}" }
  end

  # A failed Basic authentication is a 401 challenging Basic (RFC 6749 §5.2,
  # RFC 9110 §15.5.2). Any other failure is a 400 with no challenge: there is
  # no header-borne scheme it could have tried and should retry.
  def assert_client_authentication_failed(message = nil, basic: true)
    assert_response basic ? :unauthorized : :bad_request, message
    assert_equal "invalid_client", response.parsed_body["error"], message

    if basic
      assert_equal %(Basic realm="http://www.example.com/"), response.headers["WWW-Authenticate"], message
    else
      assert_nil response.headers["WWW-Authenticate"], message
    end
  end
end
