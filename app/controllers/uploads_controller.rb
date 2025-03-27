class UploadsController < ApplicationController
  include ActiveStorage::SetCurrent, BubbleScoped, BucketScoped

  before_action :set_file, only: :create

  def create
    @upload = @bubble.uploads_attachments.create! blob: create_blob!
  end

  private
    def set_file
      @file = params[:file]
    end

    def create_blob!
      ActiveStorage::Blob.create_and_upload! io: @file, filename: @file.original_filename, content_type: @file.content_type
    end
end
