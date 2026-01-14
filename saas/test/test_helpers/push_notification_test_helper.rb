module PushNotificationTestHelper
  # Assert native push notification is queued for delivery
  def assert_native_push_delivery(count: 1, &block)
    assert_enqueued_jobs count, only: ApplicationPushNotificationJob, &block
  end

  # Assert no native push notifications are queued
  def assert_no_native_push_delivery(&block)
    assert_native_push_delivery(count: 0, &block)
  end

  # Expect push notification to be delivered (using mocha)
  def expect_native_push_delivery(count: 1)
    ApplicationPushNotification.any_instance.expects(:deliver_later_to).times(count)
    yield if block_given?
  end

  # Expect no push notification delivery
  def expect_no_native_push_delivery(&block)
    expect_native_push_delivery(count: 0, &block)
  end

  # Stub the push service to avoid actual API calls
  def stub_push_services
    ActionPushNative.stubs(:service_for).returns(stub(push: true))
  end

  # Stub push service to simulate token error (device should be deleted)
  def stub_push_token_error
    push_stub = stub.tap { |s| s.stubs(:push).raises(ActionPushNative::TokenError) }
    ActionPushNative.stubs(:service_for).returns(push_stub)
  end
end
