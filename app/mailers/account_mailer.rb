class AccountMailer < ApplicationMailer
  def deletion_scheduled(cancellation)
    @account = cancellation.account
    @user = cancellation.initiated_by
    @cancellation = cancellation
    @deletion_date = cancellation.created_at + Account::Cancellable::INCINERATION_GRACE_PERIOD
    @days_remaining = (@deletion_date.to_date - Date.current).to_i

    mail(
      to: @user.identity.email_address,
      subject: "Your Fizzy account has been scheduled for deletion"
    )
  end
end
