require "test_helper"

class ClientConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "android" do
    assert_ok "/client_configurations/android_v1.json"
  end

  test "ios" do
    assert_ok "/client_configurations/ios_v1.json"
  end

  test "bad platform" do
    assert_no_route "/client_configurations/blackberry_v1.json"
  end

  test "bad version" do
    assert_no_route "/client_configurations/android_va.json"
  end

  test "nonexistent version" do
    assert_missing "/client_configurations/android_v2000.json"
    assert_missing "/client_configurations/ios_v2000.json"
  end

  private
    def assert_ok(url, cache_control: { public: true, max_age: "60" })
      get url
      assert_response :ok

      assert_kind_of Hash, response.parsed_body["settings"]
      assert_kind_of Array, response.parsed_body["rules"]

      assert_equal cache_control, response.cache_control
    end

    def assert_no_route(url)
      without_action_dispatch_exception_handling do
        assert_raises(ActionController::RoutingError) { get url }
      end
    end

    def assert_missing(url)
      without_action_dispatch_exception_handling do
        assert_raises(ActionView::MissingTemplate) { get url }
      end
    end
end
