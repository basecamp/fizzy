class Notification::BundleMailer < ApplicationMailer
  include Mailers::Unsubscribable

  helper NotificationsHelper

  def notification(bundle)
    @user = bundle.user
    @bundle = bundle
    @notifications = bundle.notifications
      .preload(:card, :creator, source: [ :board, :creator ])
      .reject { |n| n.source.nil? || n.card.nil? }
    @unsubscribe_token = @user.generate_token_for(:unsubscribe)

    if @notifications.any?
      mail \
        to: bundle.user.identity.email_address,
        subject: "Fizzy#{ " (#{ Current.account.name })" if @user.identity.accounts.many? }: New notifications"
    end
  end
end
