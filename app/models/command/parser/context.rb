class Command::Parser::Context
  attr_reader :user, :url

  def initialize(user, url:)
    @user = user
    @url = url

    extract_url_components
  end

  def cards
    if viewing_card_contents?
      user.accessible_cards.where id: params[:id]
    elsif viewing_list_of_cards?
      filter.cards.published
    else
      Card.none
    end
  end

  def filter
    user.filters.from_params(params.permit(*Filter::Params::PERMITTED_PARAMS).reverse_merge(**FilterScoped::DEFAULT_PARAMS))
  end

  def viewing_card_contents?
    controller == "cards" && action == "show"
  end

  def viewing_list_of_cards?
    controller == "cards" && action == "index"
  end

  private
    attr_reader :controller, :action, :params

    def extract_url_components
      uri = URI.parse(url || "")
      route = Rails.application.routes.recognize_path(uri.path)
      @controller = route[:controller]
      @action = route[:action]
      @params =  ActionController::Parameters.new(Rack::Utils.parse_nested_query(uri.query).merge(route.except(:controller, :action)))
    end
end
