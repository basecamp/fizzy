class Bubbles::CommentsController < ApplicationController
  include BubbleScoped

  before_action :set_comment, only: %i[ show edit update destroy ]
  before_action :ensure_authorship, only: %i[ edit update destroy ]

  def create
    @bubble.capture Comment.new(comment_params)
  end

  def show
  end

  def edit
  end

  def update
    @comment.update! comment_params
  end

  def destroy
    @comment.destroy
    redirect_to @bubble
  end

  private
    def set_comment
      # FIXME: We should be able to find directly via @bubble as a root scope
      @comment = Comment.joins(:message).where(messages: { bubble_id: @bubble.id }).find(params[:id])
    end

    def ensure_authorship
      head :forbidden if Current.user != @comment.creator
    end

    def comment_params
      params.require(:comment).permit(:body)
    end
end
