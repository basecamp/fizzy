require "test_helper"

class Account::BotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create bot user" do
    assert_difference -> { User.count } do
      post account_bots_path, params: { name: "Deploy Bot" }, as: :json
    end

    assert_response :created

    body = @response.parsed_body
    assert_equal "Deploy Bot", body["user"]["name"]
    assert_equal "bot", body["user"]["role"]
    assert body["token"].present?

    bot = User.find(body["user"]["id"])
    assert bot.bot?
    assert bot.verified?
    assert bot.identity.present?
    assert bot.identity.email_address.match?(/\Abot\+\h+@fizzy\.internal\z/)
  end

  test "bot user gets a write access token" do
    post account_bots_path, params: { name: "API Bot" }, as: :json
    assert_response :created

    body = @response.parsed_body
    token = body["token"]

    identity = Identity.find_by_permissable_access_token(token, method: "POST")
    assert_not_nil identity
  end

  test "non-admin cannot create bot" do
    logout_and_sign_in_as :david

    assert_no_difference -> { User.count } do
      post account_bots_path, params: { name: "Sneaky Bot" }, as: :json
    end

    assert_response :forbidden
  end

  test "owner can create bot" do
    logout_and_sign_in_as :jason

    assert_difference -> { User.count } do
      post account_bots_path, params: { name: "Owner Bot" }, as: :json
    end

    assert_response :created
  end

  test "destroy deactivates bot" do
    bot = users(:agora_bot)

    delete account_bot_path(bot), as: :json
    assert_response :no_content

    bot.reload
    assert_not bot.active?
    assert_nil bot.identity
  end

  test "destroy only works on bot users" do
    delete account_bot_path(users(:david)), as: :json
    assert_response :not_found
  end
end
