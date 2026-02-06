require "test_helper"

class PlanTest < ActiveSupport::TestCase
  test "free plan is free" do
    assert Plan[:free_v1].free?
  end

  test "monthly plan is not free" do
    assert_not Plan[:monthly_v1].free?
  end

  test "find plan by its price id" do
    Plan.paid.stubs(:stripe_price_id).returns("price_monthly_v1")

    assert_equal Plan.paid, Plan.find_by_price_id("price_monthly_v1")
    assert_nil Plan.find_by_price_id("unknown_price_id")
  end
end
