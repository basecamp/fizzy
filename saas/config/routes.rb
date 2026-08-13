Fizzy::Saas::Engine.routes.draw do
  Queenbee.routes(self)

  namespace :my do
    resources :devices, only: [ :index, :create, :destroy ]
  end

  # Beside "up", because it answers the same kind of question and is polled the same way.
  get "hotcellz", to: "hotcellz#show"

  namespace :admin do
    mount Audits1984::Engine, at: "/console"
    get "stats", to: "stats#show"
  end
end
