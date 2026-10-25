require "test_helper"

# Every route config/routes.rb declares with filter_path_parameters, built with its URL helper and the
# account slug Fizzy routes behind: a renamed route or parameter fails here rather than logging the
# credential.
class Fizzy::Saas::CredentialPathsTest < ActiveSupport::TestCase
  include RailsStructuredLogging::PathFilter::Assertions
  include Rails.application.routes.url_helpers

  setup { @slug = accounts("37s").slug }

  test "a join code is filtered" do
    assert_path_filtered join_path("made-up-code", script_name: @slug), "made-up-code"
  end

  test "a public board's publication key is filtered from its pages" do
    assert_path_filtered public_board_path("made-up-key", script_name: @slug), "made-up-key"
    assert_path_filtered public_board_card_path("made-up-key", 1, script_name: @slug), "made-up-key"
    assert_path_filtered public_board_columns_stream_path("made-up-key", script_name: @slug), "made-up-key"
    assert_path_filtered "#{@slug}/public/collections/made-up-key", "made-up-key"
  end

  test "a path under a declared route that no route matches is filtered too" do
    # A scanner's 404, such as /<slug>/join/<code>/xmlrpc.php
    assert_path_filtered "#{join_path("made-up-code", script_name: @slug)}/xmlrpc.php", "made-up-code"
    assert_path_filtered "#{public_board_path("made-up-key", script_name: @slug)}/wp-login.php", "made-up-key"
  end

  test "an email address confirmation token is filtered" do
    assert_path_filtered user_email_address_confirmation_path(1, "made-up-token", script_name: @slug), "made-up-token"
  end

  test "a session transfer's id and a QR code's signed link are filtered" do
    assert_path_filtered session_transfer_path("made-up-transfer"), "made-up-transfer"
    assert_path_filtered qr_code_path("made-up-link", script_name: @slug), "made-up-link"
  end

  test "an access token's reveal link is filtered" do
    assert_path_filtered my_access_token_path("made-up-signed-id"), "made-up-signed-id"
  end
end
