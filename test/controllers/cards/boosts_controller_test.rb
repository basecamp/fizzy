require "test_helper"

class Bubbles::BoostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    boost_count = bubbles(:logo).boosts_count

    assert_difference "bubbles(:logo).reload.boosts_count", +1 do
      post bubble_boosts_path(bubbles(:logo), params: { boost_count: boost_count }, format: :turbo_stream)
    end

    assert_turbo_stream action: :update, target: dom_id(bubbles(:logo), :boosts)
  end

  test "create with value" do
    boost_count = 10

    assert_changes "bubbles(:logo).reload.boosts_count", to: boost_count do
      post bubble_boosts_path(bubbles(:logo), params: { boost_count: boost_count }, format: :turbo_stream)
    end

    assert_turbo_stream action: :update, target: dom_id(bubbles(:logo), :boosts)
  end
end
