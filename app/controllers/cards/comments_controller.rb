class Cards::CommentsController < ApplicationController
  include CardScoped

  before_action :set_comment, only: %i[ show edit update destroy ]
  before_action :ensure_creatorship, only: %i[ edit update destroy ]

  def create
    @comment = @card.comments.create!(comment_params)
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
  end

  private
    def set_comment
      @comment = @card.comments.find(params[:id])
    end

    def ensure_creatorship
      head :forbidden if Current.user != @comment.creator
    end

    def comment_params
      params.expect(comment: :body)
    end
end
