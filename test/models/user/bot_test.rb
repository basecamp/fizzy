require "test_helper"

class User::BotTest < ActiveSupport::TestCase
  test "bot user is included in active scope" do
    assert_includes User.active, users(:agora_bot)
  end

  test "bot user is in bot scope" do
    assert_includes User.bot, users(:agora_bot)
  end

  test "bot user gets added to all_access boards on creation" do
    bot = User.create!(account: accounts("37s"), role: "bot", name: "Test Bot")
    assert_equal bot.account.boards.all_access.count, bot.boards.count
  end

  test "bot user does not get settings on creation" do
    bot = User.create!(account: accounts("37s"), role: "bot", name: "Test Bot")
    assert_nil bot.settings
  end

  test "bot user is always considered setup" do
    bot = users(:agora_bot)
    assert bot.setup?
  end
end
