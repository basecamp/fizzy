Rails.application.routes.draw do
  root "events#index"

  namespace :account do
    resource :cancellation, only: [ :create ]
    resource :entropy
    resource :join_code
    resource :settings
    resources :exports, only: [ :create, :show ]
    resources :imports, only: [ :new, :create, :show ]
  end

  resources :users do
    scope module: :users do
      resource :avatar
      resource :role
      resource :events

      resources :push_subscriptions

      resources :email_addresses, param: :token do
        resource :confirmation, module: :email_addresses
      end

      resources :data_exports, only: [ :create, :show ]
    end
  end

  resources :boards do
    scope module: :boards do
      resource :subscriptions
      resource :involvement
      resource :publication
      resource :entropy

      namespace :columns do
        resource :not_now
        resource :stream
        resource :closed
      end

      resources :columns
    end

    resources :cards, only: :create

    resources :webhooks do
      scope module: :webhooks do
        resource :activation, only: :create
      end
    end
  end

  resources :columns, only: [] do
    resource :left_position, module: :columns
    resource :right_position, module: :columns
  end

  namespace :columns do
    resources :cards do
      scope module: :cards do
        namespace :drops do
          resource :not_now
          resource :stream
          resource :closure
          resource :column
        end
      end
    end
  end

  namespace :cards do
    resources :previews
  end

  resources :cards do
    scope module: :cards do
      resource :draft, only: :show
      resource :board
      resource :closure
      resource :column
      resource :goldness
      resource :image
      resource :not_now
      resource :pin
      resource :publish
      resource :reading
      resource :triage
      resource :watch
      resource :reading

      resources :reactions

      resources :assignments
      resource :self_assignment, only: :create
      resources :steps
      resources :taggings

      resources :comments do
        resources :reactions, module: :comments
      end
    end
  end

  resources :tags, only: :index

  namespace :notifications do
    resource :settings
    resource :unsubscribe
  end

  resources :notifications do
    scope module: :notifications do
      get "tray", to: "trays#show", on: :collection

      resource :reading
      collection do
        resource :bulk_reading, only: :create
      end
    end
  end

  resource :search
  namespace :searches do
    resources :queries
  end

  resources :filters do
    scope module: :filters do
      collection do
        resource :settings_refresh, only: :create
      end
    end
  end

  resources :events, only: :index
  namespace :events do
    resources :days
    namespace :day_timeline do
      resources :columns, only: :show
    end
  end

  resources :qr_codes

  get "join/:code", to: "join_codes#new", as: :join
  post "join/:code", to: "join_codes#create"

  namespace :users do
    resources :joins
    resources :verifications, only: %i[ new create ]
  end

  resource :session do
    scope module: :sessions do
      resources :transfers
      resource :magic_link
      resource :menu
    end
  end

  get "/signup", to: redirect("/signup/new")

  resource :signup, only: %i[ new create ] do
    collection do
      scope module: :signups, as: :signup do
        resource :completion, only: %i[ new create ]
      end
    end
  end

  resource :landing

  namespace :my do
    resource :identity, only: :show
    resources :access_tokens
    resources :pins
    resource :timezone
    resource :menu
  end

  namespace :prompts do
    resources :cards
    resources :tags
    resources :users

    resources :boards do
      scope module: :boards do
        resources :users
      end
    end
  end

  namespace :public do
    resources :boards do
      scope module: :boards do
        namespace :columns do
          resource :not_now, only: :show
          resource :stream, only: :show
          resource :closed, only: :show
        end

        resources :columns, only: :show
      end

      resources :cards, only: :show
    end
  end

  direct :published_board do |board, options|
    route_for :public_board, board.publication.key
  end

  direct :published_card do |card, options|
    route_for :public_board_card, card.board.publication.key, card
  end

  resolve "Comment" do |comment, options|
    options[:anchor] = ActionView::RecordIdentifier.dom_id(comment)
    route_for :card, comment.card, options
  end

  resolve "Mention" do |mention, options|
    polymorphic_url(mention.source, options)
  end

  resolve "Notification" do |notification, options|
    polymorphic_url(notification.notifiable_target, options)
  end

  resolve "Event" do |event, options|
    polymorphic_url(event.eventable, options)
  end

  resolve "Webhook" do |webhook, options|
    route_for :board_webhook, webhook.board, webhook, options
  end

  # Support for legacy URLs
  get "/collections/:collection_id/cards/:id", to: redirect { |params, request| "#{request.script_name}/cards/#{params[:id]}" }
  get "/collections/:id", to: redirect { |params, request| "#{request.script_name}/boards/#{params[:id]}" }
  get "/public/collections/:id", to: redirect { |params, request| "#{request.script_name}/public/boards/#{params[:id]}" }

  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "pwa#service_worker"

  namespace :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end
end
