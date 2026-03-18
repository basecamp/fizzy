require "test_helper"

class ApplicationPlatformTest < ActiveSupport::TestCase
  NATIVE_ANDROID_UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Hotwire Native Android/1.0 bridge-components: [buttons overflow-menu form]"
  NATIVE_IOS_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Hotwire Native iOS/1.0 bridge-components: [title]"
  MOBILE_WEB_IOS_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
  DESKTOP_WEB_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  NATIVE_WITHOUT_COMPONENTS_UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Hotwire Native Android/1.0"
  NATIVE_WITH_EMPTY_COMPONENTS_UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Hotwire Native Android/1.0 bridge-components: []"
  NATIVE_WITH_MULTIPLE_LISTS_UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Hotwire Native Android/1.0 bridge-components: [buttons] metadata: [ignored]"

  test "bridge_name returns android for native android user agents" do
    assert_equal :android, platform_for(NATIVE_ANDROID_UA).bridge_name
  end

  test "bridge_name returns ios for native ios user agents" do
    assert_equal :ios, platform_for(NATIVE_IOS_UA).bridge_name
  end

  test "bridge_name is nil for non-native user agents" do
    assert_nil platform_for(MOBILE_WEB_IOS_UA).bridge_name
    assert_nil platform_for(DESKTOP_WEB_UA).bridge_name
  end

  test "bridge_components returns extracted components for native user agents" do
    assert_equal "buttons overflow-menu form", platform_for(NATIVE_ANDROID_UA).bridge_components
    assert_equal "title", platform_for(NATIVE_IOS_UA).bridge_components
  end

  test "bridge_components is blank for non-native user agents" do
    assert_equal "", platform_for(MOBILE_WEB_IOS_UA).bridge_components
    assert_equal "", platform_for(DESKTOP_WEB_UA).bridge_components
  end

  test "bridge_components is blank when native user agent does not include bridge-components metadata" do
    assert_equal "", platform_for(NATIVE_WITHOUT_COMPONENTS_UA).bridge_components
  end

  test "bridge_components supports empty lists" do
    assert_equal "", platform_for(NATIVE_WITH_EMPTY_COMPONENTS_UA).bridge_components
  end

  test "bridge_components only matches through the first closing bracket" do
    assert_equal "buttons", platform_for(NATIVE_WITH_MULTIPLE_LISTS_UA).bridge_components
  end

  private
    def platform_for(user_agent)
      ApplicationPlatform.new(user_agent)
    end
end
