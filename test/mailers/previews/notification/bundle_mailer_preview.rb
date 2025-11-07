class Notification::BundleMailerPreview < ActionMailer::Preview
  def notification
    Notification::BundleMailer.notification Notification::Bundle.take!
  end
end
