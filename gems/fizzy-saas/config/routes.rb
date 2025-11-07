Fizzy::Saas::Engine.routes.draw do
  get "/signup/new", to: redirect("/session/new")

  namespace :signup do
    resource :membership, only: %i[ new create ]
    resource :completion, only: %i[ new create ]
  end

  Queenbee.routes(self)
end
