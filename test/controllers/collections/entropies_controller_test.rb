require "test_helper"

class Collections::EntropiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @collection = collections(:writebook)
  end

  test "update" do
    put collection_entropy_path(@collection, format: :turbo_stream), params: { collection: { auto_postpone_period: 1.day } }

    assert_equal 1.day, @collection.entropy.reload.auto_postpone_period

    assert_turbo_stream action: :replace, target: dom_id(@collection, :entropy)
  end
end
