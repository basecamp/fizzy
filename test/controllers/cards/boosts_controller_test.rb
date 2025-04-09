require "test_helper"

class Cards::BoostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    boost_count = cards(:logo).boosts_count

    assert_difference "cards(:logo).reload.boosts_count", +1 do
      post card_boosts_path(cards(:logo), params: { boost_count: boost_count }, format: :turbo_stream)
    end

    assert_turbo_stream action: :update, target: dom_id(cards(:logo), :boosts)
  end

  test "create with value" do
    boost_count = 10

    assert_changes "cards(:logo).reload.boosts_count", to: boost_count do
      post card_boosts_path(cards(:logo), params: { boost_count: boost_count }, format: :turbo_stream)
    end

    assert_turbo_stream action: :update, target: dom_id(cards(:logo), :boosts)
  end
end
