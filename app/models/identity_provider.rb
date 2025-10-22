module IdentityProvider
  class Error < StandardError; end

  Token = Data.define(:id, :updated_at) do
    delegate :dig, to: :to_h

    def to_h
      { "id" => id, "updated_at" => updated_at }
    end
  end

  Tenant = Data.define(:id, :name)

  extend self

  mattr_accessor :backend, default: IdentityProvider::LocalBackend

  delegate :link, :unlink, :change_email_address, :send_magic_link, :consume_magic_link, :tenants_for, :token_for, :resolve_token, :verify_token, to: :backend
end
