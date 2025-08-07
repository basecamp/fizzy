Rails.application.routes.draw do
  resource :account do
    resource :join_code, module: :accounts

    scope module: :accounts do
      resource :settings
      resource :entropy_configuration
    end
  end

  resources :users do
    resource :role, module: :users
    resources :push_subscriptions, module: :users
  end

  resources :collections do
    scope module: :collections do
      resource :subscriptions
      resource :workflow, only: :update
      resource :involvement
      resource :publication
      resource :entropy_configuration
    end

    resources :cards
  end

  namespace :cards do
    resources :previews
    resources :drops
  end

  resources :cards do
    scope module: :cards do
      resource :engagement
      resource :goldness
      resource :image
      resource :pin
      resource :closure
      resource :publish
      resource :reading
      resource :recover
      resource :staging
      resource :watch
      resource :collection, only: :update

      resources :assignments
      resources :taggings
      resources :steps

      resources :comments do
        resources :reactions, module: :comments
      end
    end
  end

  resources :notifications do
    scope module: :notifications do
      get "tray", to: "trays#show", on: :collection
      get "settings", to: "settings#show", on: :collection

      post "readings", to: "readings#create_all", on: :collection, as: :read_all
      post "reading", to: "readings#create", on: :member, as: :read
      delete "reading", to: "readings#destroy", on: :member
    end
  end

  resource :search
  namespace :searches do
    resources :queries
  end

  resources :filters

  resources :events, only: :index
  namespace :events do
    resources :activity_summaries
    resources :days
  end

  resources :workflows do
    resources :stages, module: :workflows
  end

  resources :uploads, only: :create
  get "/u/*slug" => "uploads#show", as: :upload

  resources :qr_codes
  get "join/:join_code", to: "users#new", as: :join
  post "join/:join_code", to: "users#create"

  resource :session do
    scope module: "sessions" do
      resources :transfers, only: %i[ show update ]
      resource :launchpad, only: %i[ show update ], controller: "launchpad"
    end
  end

  namespace :signup do
    get "/" => "accounts#new"
    resources :accounts, only: %i[ new create ]
    get "/session" => "sessions#create" # redirect from Launchpad after mid-signup authentication
    resources :completions, only: %i[ new create ]
  end

  resources :users do
    scope module: :users do
      resource :avatar
    end
  end

  resources :commands do
    scope module: :commands do
      resource :undo, only: :create
    end
  end

  namespace :my do
    resources :pins
  end

  namespace :prompts do
    resources :cards
    resources :users
    resources :tags
    resources :commands

    resources :collections do
      scope module: :collections do
        resources :users
      end
    end
  end

  namespace :public do
    resources :collections do
      scope module: :collections do
        resources :card_previews
      end

      resources :cards, only: :show
    end
  end

  namespace :admin do
    resource :prompt_sandbox
  end

  direct :published_collection do |collection, options|
    route_for :public_collection, collection.publication.key
  end

  direct :published_card do |card, options|
    route_for :public_collection_card, card.collection.publication.key, card
  end

  resolve "Card" do |card, options|
    route_for :collection_card, card.collection, card, options
  end

  resolve "Comment" do |comment, options|
    options[:anchor] = ActionView::RecordIdentifier.dom_id(comment)
    route_for :collection_card, comment.card.collection, comment.card, options
  end

  resolve "Mention" do |mention, options|
    polymorphic_path(mention.source, options)
  end

  resolve "Notification" do |notification, options|
    polymorphic_path(notification.notifiable_target, options)
  end

  resolve "Event" do |event, options|
    polymorphic_path(event.target, options)
  end

  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "pwa#service_worker"

  match "/400", to: "errors#bad_request", via: :all
  match "/404", to: "errors#not_found", via: :all
  match "/406", to: "errors#not_acceptable", via: :all
  match "/422", to: "errors#unprocessable_entity", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  root "events#index"

  Queenbee.routes(self)

  namespace :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end
end
