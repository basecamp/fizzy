class Cards::Comments::ReactionsController < ApplicationController
  include CardScoped

  before_action :set_comment
  before_action :set_reactable

  with_options only: :destroy do
    before_action :set_reaction
    before_action :ensure_permission_to_administer_reaction
  end

  def index
    render "reactions/index"
  end

  def new
    render "reactions/new"
  end

  def create
    @reaction = @reactable.reactions.create!(params.expect(reaction: :content))

    respond_to do |format|
      format.turbo_stream { render "reactions/create" }
      format.json { head :created }
    end
  end

  def destroy
    @reaction.destroy

    respond_to do |format|
      format.turbo_stream { render "reactions/destroy" }
      format.json { head :no_content }
    end
  end

  private
    def set_comment
      @comment = @card.comments.find(params[:comment_id])
    end

    def set_reactable
      @reactable = @comment
    end

    def set_reaction
      @reaction = @reactable.reactions.find(params[:id])
    end

    def ensure_permission_to_administer_reaction
      head :forbidden if Current.user != @reaction.reacter
    end
end
