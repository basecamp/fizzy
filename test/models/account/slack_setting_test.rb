require "test_helper"

class Account::SlackSettingTest < ActiveSupport::TestCase
  test "allows_event? returns true for message when allow_messages is true" do
    setting = account_slack_settings(:first_account)
    assert setting.allow_messages
    assert setting.allows_event?("message")
  end

  test "allows_event? returns false for message when allow_messages is false" do
    setting = account_slack_settings(:second_account)
    setting.update!(allow_messages: false)
    assert_not setting.allows_event?("message")
  end

  test "allows_event? returns true for thread_reply when allow_thread_replies is true" do
    setting = account_slack_settings(:first_account)
    assert setting.allow_thread_replies
    assert setting.allows_event?("thread_reply")
  end

  test "allows_event? returns false for thread_reply when allow_thread_replies is false" do
    setting = account_slack_settings(:second_account)
    assert_not setting.allow_thread_replies
    assert_not setting.allows_event?("thread_reply")
  end

  test "allows_event? returns true for reaction_added when allow_reactions is true" do
    setting = account_slack_settings(:first_account)
    assert setting.allow_reactions
    assert setting.allows_event?("reaction_added")
  end

  test "allows_event? returns false for reaction_added when allow_reactions is false" do
    setting = account_slack_settings(:second_account)
    setting.update!(allow_reactions: false)
    assert_not setting.allows_event?("reaction_added")
  end

  test "allows_event? returns false for unknown event type" do
    setting = account_slack_settings(:first_account)
    assert_not setting.allows_event?("unknown_event")
  end
end
