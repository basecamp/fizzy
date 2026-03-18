class ApplicationPlatform < PlatformAgent
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

  def native?
    match? /Hotwire Native/
  end

  def windows?
    operating_system == "Windows"
  end

  def bridge_name
    case
    when native? && android? then :android
    when native? && ios?     then :ios
    end
  end

  def bridge_components
    extract_list_from_native_user_agent("bridge-components")
  end

  def type
    if native? && android?
      "native android"
    elsif native? && ios?
      "native ios"
    elsif mobile?
      "mobile web"
    else
      "desktop web"
    end
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

  private
    def extract_list_from_native_user_agent(prefix)
      if native?
        user_agent.to_s.match(/#{Regexp.escape(prefix)}: \[(.*?)\]/) { |matches| matches[1] }.to_s
      else
        ""
      end
    end
end
