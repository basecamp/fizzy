Fizzy::Saas::Engine.routes.draw do
  Queenbee.routes(self)

  namespace :my do
    resources :devices, only: [ :index, :create, :destroy ]
  end

  namespace :admin do
    mount Audits1984::Engine, at: "/console"
    get "stats", to: "stats#show"
  end
end
