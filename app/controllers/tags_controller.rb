class TagsController < ApplicationController
  def index
    @tags = Current.account.tags.all.alphabetically
  end
end
