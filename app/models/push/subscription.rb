class Push::Subscription < ApplicationRecord
  belongs_to :account, default: -> { user.account }
  belongs_to :user

  def notification(**params)
    WebPush::Notification.new(
      **params,
      badge: user.notifications.unread.count,
      endpoint: endpoint,
      p256dh_key: p256dh_key,
      auth_key: auth_key
    )
  end
end
