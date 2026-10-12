class Webhooks::ActivationsController < ApplicationController
  include BoardScoped

  skip_before_action :ensure_board_is_active
  before_action :ensure_admin

  def create
    @webhook = @board.webhooks.find(params[:webhook_id])
    @webhook.activate

    respond_to do |format|
      format.html { redirect_to @webhook }
      format.json { render "webhooks/show", status: :created }
    end
  end
end
