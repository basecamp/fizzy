class CommentsController < ApplicationController
  include CardScoped
  before_action :set_comment, only: [ :show, :edit, :update, :destroy ]
  before_action :require_own_comment, only: [ :edit, :update, :destroy ]

  def create
    @card.capture new_comment
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
    redirect_to @card
  end

  private
    def comment_params
      params.require(:comment).permit(:body)
    end

    def new_comment
      Comment.new(comment_params)
    end

    def set_comment
      @comment = Comment.joins(:message)
                        .where(messages: { card_id: @card.id })
                        .find(params[:id])
    end

    def require_own_comment
      head :forbidden unless Current.user == @comment.creator
    end
end
