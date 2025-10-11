Fizzy::Saas::Engine.routes.draw do
  resource :signup, only: %i[ new create ] do
    scope module: :signups do
      collection do
        resource :completion, only: %i[ new create ], as: :signup_completion
      end
    end
  end
  Queenbee.routes(self)
end
