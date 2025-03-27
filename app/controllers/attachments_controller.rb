class AttachmentsController < ApplicationController
  include ActiveStorage::SetCurrent

  before_action :set_attachment, only: :show

  def show
    expires_in 5.minutes, public: true
    redirect_to @attachment.url
  end

  private
    def set_attachment
      @attachment = ActiveStorage::Attachment.find_by! slug: "#{params[:slug]}.#{params[:format]}"
    end
end
