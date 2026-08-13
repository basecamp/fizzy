Fizzy::Saas::Engine.routes.draw do
  Queenbee.routes(self)

  namespace :my do
    resources :devices, only: [ :index, :create, :destroy ]
  end

  # Beside "up", because it answers the same kind of question — but staff-only, since it reports what the
  # cell's image carries.
  get "hotcellz", to: "hotcellz#show"

  namespace :admin do
    mount Audits1984::Engine, at: "/console"
    get "stats", to: "stats#show"
  end
end
