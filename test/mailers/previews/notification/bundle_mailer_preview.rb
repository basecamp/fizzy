class Notification::BundleMailerPreview < ActionMailer::Preview
  def notification
    ApplicationRecord.current_tenant = "897362094"
    Notification::BundleMailer.notification Notification::Bundle.take!
  end
end
