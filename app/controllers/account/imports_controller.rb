class Account::ImportsController < ApplicationController
  layout "public"

  disallow_account_scope only: %i[ new create ]
  allow_unauthorized_access only: :show
  before_action :set_import, only: %i[ show ]
  before_action :ensure_accessed_by_owner, only: %i[ show ]

  def new
  end

  def create
    signup = Signup.new(identity: Current.identity, full_name: "Import", skip_account_seeding: true)

    if signup.complete
      start_import(signup.account)
    else
      render :new, alert: "Couldn't create account."
    end
  end

  def show
  end

  private
    def set_import
      @import = Current.account.imports.find(params[:id])
    end

    def ensure_accessed_by_owner
      head :forbidden unless @import.identity == Current.identity
    end

    def start_import(account)
      import = nil

      Current.set(account: account) do
        import = account.imports.create!(identity: Current.identity, file: params[:file])
        import.process_later
      end

      redirect_to account_import_path(import, script_name: account.slug)
    end
end
