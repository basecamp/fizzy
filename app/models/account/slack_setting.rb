class Account::SlackSetting < ApplicationRecord
  belongs_to :account

  def allows_event?(event_type)
    case event_type
    when "message" then allow_messages
    when "thread_reply" then allow_thread_replies
    when "reaction_added" then allow_reactions
    else false
    end
  end
end
