Fizzy::Saas::Engine.routes.draw do
  Queenbee.routes(self)

  namespace :my do
    resources :devices, only: [ :index, :create, :destroy ]
  end

  # Beside "up", because it answers the same kind of question and is polled the same way. The work-socket
  # round trips are a separate action because they fork a worker, and only staff may spend one.
  get "hotcellz", to: "hotcellz#show"
  get "hotcellz/test", to: "hotcellz#test"

  namespace :admin do
    mount Audits1984::Engine, at: "/console"
    get "stats", to: "stats#show"
  end
end
