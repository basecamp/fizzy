require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  browser_options = Selenium::WebDriver::Chrome::Options.new.tap do |opts|
    opts.add_argument("--window-size=1200,800")
    opts.add_argument("--disable-extensions")
    # Disable non-foreground tabs from getting a lower process priority
    opts.add_argument("--disable-renderer-backgrounding")
    # Normally, Chrome will treat a 'foreground' tab instead as backgrounded if the surrounding
    # window is occluded (aka visually covered) by another window. This flag disables that.
    opts.add_argument("--disable-backgrounding-occluded-windows")
    # Suppress all permission prompts by automatically denying them.
    opts.add_argument("--deny-permission-prompts")
    opts.add_argument("--enable-automation")
  end

  Capybara.register_driver :chrome_headless do |app|
    browser_options.add_argument("--headless")
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  Capybara.register_driver :chrome do |app|
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  if ENV["SYSTEM_TESTS_BROWSER"]
    driven_by :chrome, screen_size: [ 1200, 1000 ]
  else
    driven_by :chrome_headless, screen_size: [ 1200, 1000 ]
  end

  setup do
    # Set ActiveStorage::Current.url_options for system tests
    # This is normally set by ActiveStorageControllerExtensions in each request,
    # but system tests need it set globally
    Capybara.server_host = "127.0.0.1"
    Capybara.app_host = "http://#{Capybara.server_host}:#{Capybara.server_port}"

    ActiveStorage::Current.url_options = {
      protocol: "http",
      host: Capybara.server_host,
      port: Capybara.server_port,
      script_name: "" # Will be set per-test if needed
    }
  end
end
