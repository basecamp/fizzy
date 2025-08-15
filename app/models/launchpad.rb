# lifted from bc3 app/models/launchpad.rb
module Launchpad
  extend self

  delegate :url, to: "SignalId.launchpad"

  def login_url(product: false, account: nil, **params)
    signal_account = account.is_a?(SignalId::Account) ? account : account&.signal_account
    url product_account_path("/signin", product:, signal_account:), params
  end

  def authentication_url(**params)
    url "/authenticate", params.merge(product: :fizzy)
  end

  def product_account_path(path = nil, product: false, signal_account: nil)
    product_path = "/fizzy" if product || signal_account
    account_path = "/#{signal_account.id}" if signal_account
    [ product_path, account_path, path ].compact.join
  end
end
