class Conversations::MessagesController < ApplicationController
  include StaffOnly

  before_action :set_conversation

  def index
    @messages = paginated_messages(@conversation.messages)
  end

  def create
    @conversation.ask(question, **message_params)
  rescue Ai::Quota::UsageExceedsQuotaError
    render json: { error: "You've depleted your quota" }, status: :too_many_requests
  rescue Conversation::InvalidStateError
    render json: { error: "Fizzy is still working on an answer to your last question" }, status: :conflict
  end

  private
    def set_conversation
      @conversation = Current.user.conversation
    end

    def paginated_messages(messages)
      if params[:before]
        messages.page_before(messages.find(params[:before]))
      else
        messages.last_page
      end
    end

    def question
      message_params[:content]
    end

    def message_params
      params.require(:conversation_message).permit(:content, :client_message_id)
    end
end
