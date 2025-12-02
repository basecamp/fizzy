module UsersHelper
  def role_display_name(user)
    case user.role
    when "admin" then "Administrator"
    else user.role.titleize
    end
  end

  def access_token_permission_options
    Identity::AccessToken.permissions.keys.map { [ it.humanize, it ] }
  end
end
