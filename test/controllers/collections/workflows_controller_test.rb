require "test_helper"

class Collections::WorkflowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    collection = collections(:writebook)

    patch collection_workflow_url(collection), params: { collection: { workflow_id: workflows(:on_call).id } }

    assert_redirected_to cards_path(collection_ids: [ collection.id ])
    assert_equal workflows(:on_call), collection.reload.workflow
  end
end
