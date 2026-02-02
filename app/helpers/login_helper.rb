module LoginHelper
  def login_url
    main_app.new_session_path(script_name: nil)
  end

  def logout_url
    main_app.new_session_path
  end

  def redirect_to_login_url
    redirect_to login_url, allow_other_host: true
  end

  def redirect_to_logout_url
    redirect_to logout_url, allow_other_host: true
  end
end
