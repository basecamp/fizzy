class Comments::ReactionsController < ApplicationController
  before_action :set_comment

  def index
    @reactions = @comment.reactions.ordered.includes(:reacter)
  end

  def new
  end

  def create
    @reaction = @comment.reactions.create!(reaction_params)

    broadcast_create
    redirect_to collection_card_comment_reactions_url(@comment.card.collection, @comment.card, @comment)
  end

  def destroy
    @reaction = @comment.reactions.find(params[:id])
    @reaction.destroy!

    broadcast_remove
  end

  private
    def set_comment
      @comment = Current.account.comments.find(params[:comment_id])
    end

    def reaction_params
      params.require(:reaction).permit(:content)
    end

    def broadcast_create
      @reaction.broadcast_append_to @reaction.comment, :comments,
        target: "reactions_comment_#{@comment.id}", partial: "comments/reactions/reaction", locals: { comment: @comment }
    end

    def broadcast_remove
      @reaction.broadcast_remove_to @reaction.comment, :comments
    end
end
