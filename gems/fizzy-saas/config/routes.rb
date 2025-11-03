Fizzy::Saas::Engine.routes.draw do
  resource :signup, only: %i[ new create ] do
    scope module: :signups, as: :signup do
      collection do
        resource :membership, only: %i[ new create ]
        resource :completion, only: %i[ new create ]
      end
    end
  end

  Queenbee.routes(self)
end
