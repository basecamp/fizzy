class ConversationsController < AdminController
  def create
    Current.user.start_or_continue_conversation
  end

  def show
    @conversation = Current.user.conversation
  end
end
