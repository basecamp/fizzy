class Cards::TaggingsController < ApplicationController
  include CardScoped

  def new
    @tags = Current.account.tags.alphabetically
  end

  def create
    @card.toggle_tag_with sanitized_tag_title_param
  end

  private
    def sanitized_tag_title_param
      params.required(:tag_title).strip.gsub(/\A#/, "")
    end
end
