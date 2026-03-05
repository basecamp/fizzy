Fizzy::Saas::Engine.routes.draw do
  Queenbee.routes(self)

  namespace :my do
    resources :devices, only: [ :index, :create, :destroy ]
  end

  namespace :admin do
    mount Audits1984::Engine, at: "/console"
    get "stats", to: "stats#show"
    resource :account_search, only: :create
    resources :accounts do
      resource :overridden_limits, only: :destroy
      resource :billing_waiver, only: [ :create, :destroy ]
    end
  end
end
