module LoginHelper
  def login_url
    if ApplicationRecord.current_tenant
      if Rails.application.config.x.local_authentication
        new_session_path
      else
        Launchpad.login_url(product: true, account: Account.sole)
      end
    else
      Launchpad.login_url(product: true)
    end
  end

  def redirect_to_login_url
    redirect_to login_url, allow_other_host: true
  end
end
