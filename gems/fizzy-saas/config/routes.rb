Fizzy::Saas::Engine.routes.draw do
  resource :signup, only: %i[ new create ] do
    scope module: :signups do
      collection do
        resource :completion, only: %i[ new create ], as: :signup_completion
      end
    end
  end

  Queenbee.routes(self)

  post "identities/link", to: "identities#link", as: :link_identity
  post "identities/unlink", to: "identities#unlink", as: :unlink_identity
  post "identities/change_email_address", to: "identities#change_email_address", as: :change_identity_email_address
  post "identities/send_magic_link", to: "identities#send_magic_link", as: :send_magic_link
end
