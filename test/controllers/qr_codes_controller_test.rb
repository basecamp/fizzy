require "test_helper"

class QrCodesControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    join_code = account_join_codes(:"37s")
    account = accounts("37s")
    url = join_url(code: join_code.code, script_name: account.slug, host: "app.fizzy.do")
    signed_token = QrCodeLink.new(url).signed

    get qr_code_path(signed_token)

    assert_response :success
    assert_match %r{image/svg\+xml}, response.content_type
    assert_includes response.body, "<svg"
  end
end
