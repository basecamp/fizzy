class ApplicationPlatform < PlatformAgent
  SCOPED_STYLESHEET_PATHS = {}

  def ios?
    match? /iPhone|iPad/
  end

  def android?
    match? /Android/
  end

  def mac?
    match? /Macintosh/
  end

  def chrome?
    user_agent.browser.match? /Chrome/
  end

  def edge?
    user_agent.browser.match? /Edg/
  end

  def firefox?
    user_agent.browser.match? /Firefox|FxiOS/
  end

  def safari?
    user_agent.browser.match? /Safari/
  end

  def mobile?
    ios? || android?
  end

  def desktop?
    !mobile?
  end

  def windows?
    operating_system == "Windows"
  end

  def ios_app?
    match? /Fizzy iOS/
  end

  def android_app?
    match? /Fizzy Android/
  end

  def mobile_app?
    ios_app? || android_app?
  end

  def operating_system
    case user_agent.platform
    when /Android/   then "Android"
    when /iPad/      then "iPad"
    when /iPhone/    then "iPhone"
    when /Macintosh/ then "macOS"
    when /Windows/   then "Windows"
    when /CrOS/      then "ChromeOS"
    else
      os =~ /Linux/ ? "Linux" : os
    end
  end

  def stylesheet_paths
    scoped_stylesheet_paths("web") +
    (mobile_app? ? scoped_stylesheet_paths("mobile_app") : []) +
    scoped_stylesheet_paths(stylesheet_asset_name)
  end

  private
    def stylesheet_asset_name
      case
      when android_app? then "android"
      when ios_app?     then "ios"
      else                   "desktop"
      end
    end

    def scoped_stylesheet_paths(scope = css_asset_name)
      # Allow new stylesheets to be added in dev/test without restarting server
      SCOPED_STYLESHEET_PATHS.clear if Rails.env.development?

      SCOPED_STYLESHEET_PATHS[scope] ||=
        Rails.root.join("app/assets/stylesheets").then do |stylesheet_root|
          stylesheet_root.glob("#{scope}/**/*.css").collect do |path|
            path.to_s.remove(stylesheet_root.to_s + "/", ".css")
          end
        end
    end
end
