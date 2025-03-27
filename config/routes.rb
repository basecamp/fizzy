Rails.application.routes.draw do
  root "events#index"

  resource :account do
    scope module: :accounts do
      resource :join_code
      resources :users
    end
  end

  resolve "Bubble" do |bubble, options|
    route_for :bucket_bubble, bubble.bucket, bubble, options
  end

  resolve "Comment" do |comment, options|
    options[:anchor] = ActionView::RecordIdentifier.dom_id(comment)
    route_for :bucket_bubble, comment.bubble.bucket, comment.bubble, options
  end

  resources :bubbles
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
    end

    resources :bubbles do
      resources :boosts
      resources :comments do
        resources :reactions, module: :comments
      end
      resource :readings, only: :create
      resources :uploads, only: :create

      scope module: :bubbles do
        resource :image
        resource :pop
        resource :publish
        resource :recover
        resource :stage_picker
        resources :stagings
        resource :watch
        resource :pin, only: [ :show, :create, :destroy ]
      end

      namespace :assignments, as: :assignment do
        resources :toggles
      end

      namespace :taggings, as: :tagging do
        resources :toggles
      end
    end
  end

  get "/u/*slug" => "attachments#show", as: :attachment

  resources :events, only: :index
  namespace :events do
    resources :days
  end

  resources :filters
  resource :first_run
  resources :qr_codes

  resource :session do
    scope module: "sessions" do
      resources :transfers, only: %i[ show update ]
    end
  end

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

  namespace :bubbles do
    namespace :pins do
      resource :tray, only: :show
    end
    resources :pins, only: :index
  end

  resource :terminal, only: [ :show, :edit ]
end
