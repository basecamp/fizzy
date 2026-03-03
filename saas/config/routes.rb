Fizzy::Saas::Engine.routes.draw do
  Queenbee.routes(self)

  namespace :my do
    resources :devices, only: [ :index, :create, :destroy ]
  end

  # Legacy /devices routes for mobile apps not yet updated to /my/devices
  get "/devices", to: redirect("/my/devices")
  post "/devices", to: "my/devices#create"
  delete "/devices/:id", to: "my/devices#destroy"

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
