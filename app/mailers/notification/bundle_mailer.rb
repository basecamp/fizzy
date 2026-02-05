class Notification::BundleMailer < ApplicationMailer
  include Mailers::Unsubscribable

  helper NotificationsHelper

  def notification(bundle)
    @user = bundle.user
    @bundle = bundle
    @notifications = bundle.notifications
    @unsubscribe_token = @user.generate_token_for(:unsubscribe)

    mail \
      to: bundle.user.identity.email_address,
      subject: @user.identity.accounts.many? ? I18n.t("mailers.notification.bundle_subject_with_account", account_name: Current.account.name) : I18n.t("mailers.notification.bundle_subject")
  end
end
