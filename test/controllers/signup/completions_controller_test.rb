require "test_helper"

class Signup::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signup = Signup.new(email_address: "newuser@example.com", full_name: "New User")

    @signup.create_identity || raise("Failed to create identity")

    sign_in_as @signup.identity
  end

  test "new" do
    untenanted do
      get new_signup_completion_path
    end

    assert_response :success
  end

  test "new for a member of the admin group with single sign-on" do
    current_session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_groups: [ "/fizzy/admin" ])

    with_single_sign_on admin_group: "/fizzy/admin" do
      untenanted do
        get new_signup_completion_path
      end
    end

    assert_response :success
  end

  test "create outside the admin group with single sign-on" do
    current_session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_groups: [ "/sales" ])

    with_single_sign_on admin_group: "/fizzy/admin" do
      untenanted do
        assert_no_difference -> { Account.count } do
          post signup_completion_path, params: { signup: { full_name: @signup.full_name } }
        end

        assert_redirected_to session_menu_url
      end
    end

    assert_equal "Only members of the SSO group /fizzy/admin can create accounts.", flash[:alert]
  end

  test "create via JSON without an admin group with single sign-on" do
    current_session.update!(single_sign_on_authenticated_at: Time.current)

    with_single_sign_on do
      untenanted do
        assert_no_difference -> { Account.count } do
          post signup_completion_path(format: :json), params: { signup: { full_name: @signup.full_name } }
        end
      end
    end

    assert_response :forbidden
    assert_equal "account_creation_not_allowed", response.parsed_body["error"]
  end

  test "create" do
    untenanted do
      post signup_completion_path, params: {
        signup: {
          full_name: @signup.full_name
        }
      }
    end

    assert_response :redirect, "Valid params should redirect"
  end

  test "shows welcome letter after signup" do
    untenanted do
      post signup_completion_path, params: {
        signup: {
          full_name: @signup.full_name
        }
      }
    end

    assert flash[:welcome_letter]
  end

  test "create with blank name" do
    untenanted do
      post signup_completion_path, params: {
        signup: {
          full_name: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".txt-negative" do
      assert_select "li", text: "Full name can't be blank"
    end
  end

  test "create via JSON" do
    untenanted do
      assert_difference -> { Account.count }, +1 do
        post signup_completion_path(format: :json), params: {
          signup: {
            full_name: @signup.full_name
          }
        }
      end
    end

    assert_response :created
  end

  test "create via JSON with blank name" do
    untenanted do
      assert_no_difference -> { Account.count } do
        post signup_completion_path(format: :json), params: {
          signup: {
            full_name: ""
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_includes @response.parsed_body["errors"], "Full name can't be blank"
  end
end
