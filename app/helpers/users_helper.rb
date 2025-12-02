module UsersHelper
  def role_display_name(user)
    case user.role
    when "admin" then "Administrator"
    else user.role.titleize
    end
  end
end
