# Add this test to test/controllers/boards_controller_test.rb
#
# Tests that the page title (rendered in layout) refreshes when an account
# is renamed. Without Current.account in the ETag, the browser would
# serve cached response with a stale account name in the title.

test "invalidates page title cache when account updates" do
  get board_path(boards(:writebook))
  etag = response.headers["ETag"]

  accounts("37s").update!(name: "Renamed Account")

  get board_path(boards(:writebook)), headers: { "If-None-Match" => etag }
  assert_response :success
end
