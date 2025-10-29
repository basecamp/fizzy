require "test_helper"

class Admin::PromptSandboxesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show renders the form with default prompt" do
    get admin_prompt_sandbox_path

    assert_response :success
  end

  test "create processes prompt and renders show with summary" do
    post admin_prompt_sandbox_path, params: { prompt: "Test prompt for summarization" }

    assert_response :redirect
  end

  test "non-staff user gets forbidden on show" do
    users(:kevin).identity.update! email_address: "kevin@hey.com"

    get admin_prompt_sandbox_path

    assert_response :forbidden
  end

  test "non-staff user gets forbidden on create" do
    users(:kevin).identity.update! email_address: "kevin@hey.com"

    post admin_prompt_sandbox_path, params: { prompt: "Test prompt for summarization" }

    assert_response :forbidden
  end
end
