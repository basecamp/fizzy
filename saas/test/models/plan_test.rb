require "test_helper"

class PlanTest < ActiveSupport::TestCase
  test "free plan is free" do
    assert Plan[:free_v1].free?
  end

  test "monthly plan is not free" do
    assert_not Plan[:monthly_v1].free?
  end
end
