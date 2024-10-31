Rails.application.routes.draw do
  root "views#index"

  resource :account do
    scope module: :accounts do
      resource :join_code
      resources :users
    end
  end

  resources :bubbles

  resources :buckets do
    resources :bubbles do
      resources :assignments
      resources :boosts
      resources :comments
      resources :tags, shallow: true

      scope module: :bubbles do
        resource :image
        resource :pop
        resource :stage_picker
        resources :stagings
      end
    end

    resources :tags, only: :index
  end

  resource :first_run
  resource :session

  resources :users do
    scope module: :users do
      resource :avatar
    end
  end

  resources :views

  resources :workflows do
    resources :stages, module: :workflows
  end

  get "join/:join_code", to: "users#new", as: :join
  post "join/:join_code", to: "users#create"
  get "up", to: "rails/health#show", as: :rails_health_check
end
