Fizzy::Saas::Engine.routes.draw do
  resource :signup, only: [ :new, :create ]
  Queenbee.routes(self)
end
