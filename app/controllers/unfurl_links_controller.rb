class UnfurlLinksController < ApplicationController
  rate_limit to: 50, within: 1.hour, by: -> { Current.user.id }

  def create
    link = Link.unfurl(url_param)

    if link.unfurler.requires_setup?
      render \
        json: { error: :unfurler_requires_setup, config: link.unfurler.setup_config }, 
        status: :unprocessable_entity
    elsif link.metadata
      render json: link.metadata
    else
      head :no_content
    end
  end

  private
    def url_param
      params.require(:url)
    end
end
