require "test_helper"

# config/cable.yml uses `adapter: test` in the test env, but beta/staging/production use
# `adapter: solid_cable`. So the normal channel/connection tests (which run through
# ActionCable::Connection::TestCase) never exercise the real solid_cable subscription
# adapter, and a green suite says nothing about whether it works against the installed
# Rails.
#
# This guards the adapter against ActionCable::SubscriptionAdapter::Base contract changes on
# Rails upgrades. rails/rails 96b3add356 ("Extract async executor from Action Cable
# event_loop") dropped @server from the adapter base in favor of @executor/@config; older
# solid_cable releases still called @server.mutex / @server.event_loop, so on Rails edge
# every WebSocket connect raised `undefined method 'mutex' for nil` — a break that only
# surfaced in beta because tests use the `test` adapter.
class SolidCableAdapterTest < ActiveSupport::TestCase
  # Stand-in so we exercise the adapter's mutex/executor resolution (the code that broke)
  # without starting the real listener's DB-polling thread — the test env's cable database
  # has no solid_cable_messages table (it uses adapter: test).
  class FakeListener
    def add_subscriber(*); end
    def shutdown; end
  end

  test "subscription adapter resolves mutex/executor against the installed Action Cable" do
    adapter = ActionCable::SubscriptionAdapter::SolidCable.new(ActionCable.server)
    ActionCable::SubscriptionAdapter::SolidCable::Listener.stubs(:new).returns(FakeListener.new)

    assert_nothing_raised do
      adapter.subscribe("fizzy:solid_cable_adapter_regression", ->(_message) { })
    end
    adapter.shutdown
  end
end
