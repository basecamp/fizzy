Rails.application.routes.draw do
  namespace :account do
    resource :join_code
    resource :settings
    resource :entropy
  end

  resources :users do
    scope module: :users do
      resource :avatar
      resource :role
      resource :events

      resources :push_subscriptions
    end
  end

  resource :landing

  resources :collections do
    scope module: :collections do
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
      resource :goldness
      resource :image
      resource :pin
      resource :closure
      resource :not_now
      resource :triage
      resource :publish
      resource :reading
      resource :watch
      resource :collection
      resource :column

      resources :assignments
      resources :taggings
      resources :steps

      resources :comments do
        resources :reactions, module: :comments
      end
    end
  end

  # Redirect old card URLs from /collections/:collection_id/cards/:id to /cards/:id
  get "/collections/:collection_id/cards/:id", to: redirect { |params, request| "#{request.script_name}/cards/#{params[:id]}" }

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
  end

  resources :qr_codes

  get "join/:tenant/:code", to: "join_codes#new", as: :join
  post "join/:tenant/:code", to: "join_codes#create"

  namespace :users do
    resources :joins
  end

  resource :session do
    scope module: :sessions do
      resources :transfers
      resource :magic_link
      resource :menu
    end
  end

  resources :commands

  resource :conversation do
    scope module: :conversations do
      resources :messages
    end
  end

  scope module: :memberships, path: "memberships/:membership_id" do
    resource :unlink, only: %i[ show create ], controller: :unlink, as: :unlink_membership

    resources :email_addresses, param: :token do
      resource :confirmation, module: :email_addresses
    end
  end

  namespace :my do
    resources :pins
    resource :timezone
    resource :menu
  end

  namespace :prompts do
    resources :cards
    resources :users
    resources :tags

    resources :collections do
      scope module: :collections do
        resources :users
      end
    end
  end

  namespace :public do
    resources :collections do
      scope module: :collections do
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

  namespace :admin do
  end

  direct :published_collection do |collection, options|
    route_for :public_collection, collection.publication.key
  end

  direct :published_card do |card, options|
    route_for :public_collection_card, card.collection.publication.key, card
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
    route_for :collection_webhook, webhook.collection, webhook, options
  end

  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "pwa#service_worker"

  root "events#index"

  unless Rails.application.config.x.oss_config
    mount Fizzy::Saas::Engine, at: "/", as: "saas"
  end

  namespace :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end
end
