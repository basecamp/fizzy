require "test_helper"

class Account::BotAccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @bot = users(:agora_bot)
  end

  test "create generates a new token for the bot" do
    assert_difference -> { @bot.identity.access_tokens.count } do
      post account_bot_access_tokens_path(@bot), params: { access_token: { description: "CI token", permission: "read" } }
    end

    assert_response :redirect
    assert_redirected_to %r{/account/bots/#{@bot.id}\?token=}

    token = @bot.identity.access_tokens.last
    assert_equal "CI token", token.description
    assert_equal "read", token.permission
  end

  test "destroy revokes a token" do
    token = @bot.identity.access_tokens.create!(description: "Temp", permission: :write)

    assert_difference -> { @bot.identity.access_tokens.count }, -1 do
      delete account_bot_access_token_path(@bot, token)
    end

    assert_redirected_to account_bot_path(@bot)
  end

  test "non-admin cannot create bot tokens" do
    logout_and_sign_in_as :david

    assert_no_difference -> { @bot.identity.access_tokens.count } do
      post account_bot_access_tokens_path(@bot), params: { access_token: { description: "Sneaky", permission: "write" } }
    end

    assert_response :forbidden
  end

  test "non-admin cannot revoke bot tokens" do
    logout_and_sign_in_as :david
    token = @bot.identity.access_tokens.create!(description: "Protected", permission: :write)

    assert_no_difference -> { @bot.identity.access_tokens.count } do
      delete account_bot_access_token_path(@bot, token)
    end

    assert_response :forbidden
  end
end
