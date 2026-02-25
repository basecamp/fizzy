class Cards::CommentsController < ApplicationController
  include CardScoped

  before_action :set_comment, only: %i[ show edit update destroy ]
  before_action :ensure_creatorship, only: %i[ edit update destroy ]
  before_action :ensure_card_is_commentable, only: :create

  def index
    set_page_and_extract_portion_from @card.comments.chronologically
  end

  def create
    @comment = @card.comments.create!(comment_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :created, location: card_comment_path(@card, @comment, format: :json) }
    end
  end

  def show
  end

  def edit
  end

  def update
    @comment.update! comment_params

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @comment.destroy

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def set_comment
      @comment = @card.comments.find(params[:id])
    end

    def ensure_creatorship
      head :forbidden if Current.user != @comment.creator
    end

    def ensure_card_is_commentable
      head :forbidden unless @card.commentable?
    end

    def comment_params
      params.expect(comment: [ :body, :created_at ])
    end
end
