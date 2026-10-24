require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "service worker fetches storage with CORS mode by default" do
    untenanted { get "/service-worker.js" }

    assert_response :success
    assert_match 'fetchOptions: { mode: "cors" }', response.body
  end

  test "service worker omits CORS fetch mode when disabled" do
    switch_env "SERVICE_WORKER_CORS_ENABLED", "false" do
      untenanted { get "/service-worker.js" }
    end

    assert_response :success
    assert_no_match(/mode: "cors"/, response.body)
  end

  test "service worker carries the rendering version, so a new one clears offline pages rendered under the old" do
    untenanted { get "/service-worker.js" }

    assert_response :success
    assert_includes response.body, %(const RENDERING_VERSION = "#{ApplicationController::RENDERING_VERSION}")
    assert_includes response.body, "TurboOffline.serviceWorker.clearCache()"
  end

  private
    def switch_env(key, value)
      old, ENV[key] = ENV[key], value
      yield
    ensure
      ENV[key] = old
    end
end
