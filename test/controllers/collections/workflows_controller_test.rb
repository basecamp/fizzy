require "test_helper"

class Buckets::WorkflowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    bucket = buckets(:writebook)

    patch bucket_workflow_url(bucket), params: { bucket: { workflow_id: workflows(:on_call).id } }

    assert_redirected_to bubbles_path(bucket_ids: [ bucket.id ])
    assert_equal workflows(:on_call), bucket.reload.workflow
  end
end
