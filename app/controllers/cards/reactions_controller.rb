class Cards::ReactionsController < ApplicationController
  include CardScoped

  with_options only: :destroy do
    before_action :set_reaction
    before_action :ensure_permission_to_administer_reaction
  end

  def index
  end

  def new
  end

  def create
    @reaction = @card.reactions.create!(params.expect(reaction: :content))

    respond_to do |format|
      format.turbo_stream
      format.json { head :created }
    end
  end

  def destroy
    @reaction.destroy

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def set_reaction
      @reaction = @card.reactions.find(params[:id])
    end

    def ensure_permission_to_administer_reaction
      head :forbidden if Current.user != @reaction.reacter
    end
end
