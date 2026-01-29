class ImportsController < ApplicationController
  disallow_account_scope

  layout "public"

  def new
  end

  def create
    account = create_account_for_import

    Current.set(account: account) do
      @import = account.imports.create!(identity: Current.identity, file: params[:file])
    end

    @import.perform_later
    redirect_to import_path(@import)
  end

  def show
    @import = Current.identity.imports.find(params[:id])
  end

  private
    def create_account_for_import
      Account.create_with_owner(
        account: { name: account_name_from_zip },
        owner: { name: Current.identity.email_address.split("@").first, identity: Current.identity }
      )
    end

    def account_name_from_zip
      Zip::File.open(params[:file].tempfile.path) do |zip|
        entry = zip.find_entry("data/account.json")
        JSON.parse(entry.get_input_stream.read)["name"]
      end
    end
end
