class Prompts::TagsController < ApplicationController
  def index
    @tags = Current.account.tags.all.alphabetically

    if stale? etag: @tags
      render layout: false
    end
  end
end
