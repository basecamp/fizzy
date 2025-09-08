class ConversationsController < ApplicationController
  include StaffOnly

  def create
    Current.user.start_or_continue_conversation
  end

  def show
    @conversation = Current.user.conversation
  end
end
