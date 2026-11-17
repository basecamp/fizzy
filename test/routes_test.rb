require "test_helper"

class RouteTest < ActionDispatch::IntegrationTest
  test "account/join_code" do
    assert_recognizes({ controller: "account/join_codes", action: "show" }, "/account/join_code")
  end

  test "account/settings" do
    assert_recognizes({ controller: "account/settings", action: "show" }, "/account/settings")
  end

  test "account/entropy" do
    assert_recognizes({ controller: "account/entropies", action: "show" }, "/account/entropy")
  end

  test "columns/cards exposes no parent routes" do
    assert_empty Rails.application.routes.routes.select { |route| route.defaults[:controller] == "columns/cards" }

    error = assert_raises ActionController::RoutingError do
      Rails.application.routes.recognize_path("/columns/cards/123", method: :get)
    end
    assert_match /No route matches/, error.message
  end

  test "columns/cards/drops routes remain nested under cards" do
    assert_recognizes({ controller: "columns/cards/drops/columns", action: "create", card_id: "123" }, { path: "/columns/cards/123/drops/column", method: :post })
  end

  test "every route has a controller" do
    controllers = Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }.uniq

    missing = controllers.reject { |controller| "#{controller.camelize}Controller".safe_constantize }
    assert_empty missing
  end
end
