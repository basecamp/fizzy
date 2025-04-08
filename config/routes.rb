Rails.application.routes.draw do
  root "events#index"

  resource :account do
    scope module: :accounts do
      resource :join_code
      resources :users
    end
  end

  namespace :bubbles do
    resources :previews
  end

  resources :bubbles do
    scope module: :bubbles do
      resource :engagement
      resource :image
      resource :pin
      resource :pop
      resource :publish
      resource :reading
      resource :recover
      resource :watch

      resources :assignments
      resources :boosts
      resources :stagings
      resources :taggings
    end
  end

  resources :notifications, only: :index
  namespace :notifications do
    resource :tray, only: :show
    resource :mark_all_read, only: :create
    resources :mark_read, only: :create
    resource :settings, only: :show
  end

  resources :notifications do
    member do
      post :mark_read
    end
  end

  resources :buckets do
    scope module: :buckets do
      resource :subscriptions
      resource :workflow, only: :update
      resource :involvement
    end

    resources :bubbles do
      resources :comments do
        resources :reactions, module: :comments
      end
    end
  end

  resources :events, only: :index
  namespace :events do
    resources :days
  end

  resources :filters
  resource :first_run
  resources :qr_codes

  namespace :my do
    resources :pins
  end

  resource :session do
    scope module: "sessions" do
      resources :transfers, only: %i[ show update ]
    end
  end

  resources :uploads, only: :create
  get "/u/*slug" => "uploads#show", as: :upload

  resources :users do
    scope module: :users do
      resource :avatar
    end
  end

  resources :workflows do
    resources :stages, module: :workflows
  end

  get "join/:join_code", to: "users#new", as: :join
  post "join/:join_code", to: "users#create"
  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  resource :terminal, only: [ :show, :edit ]

  resolve "Bubble" do |bubble, options|
    route_for :bucket_bubble, bubble.bucket, bubble, options
  end

  resolve "Comment" do |comment, options|
    options[:anchor] = ActionView::RecordIdentifier.dom_id(comment)
    route_for :bucket_bubble, comment.bubble.bucket, comment.bubble, options
  end
end
