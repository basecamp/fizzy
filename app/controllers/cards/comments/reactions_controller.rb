class Cards::Comments::ReactionsController < ApplicationController
  include CardScoped

  before_action :set_comment

  def index
  end

  def new
  end

  def create
    @reaction = @comment.reactions.create!(params.expect(reaction: :content))
  end

  def destroy
    @reaction = @comment.reactions.find(params[:id])
    @reaction.destroy
  end

  private
    def set_comment
      @comment = @card.comments.find(params[:comment_id])
    end
end
