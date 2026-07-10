# frozen_string_literal: true

ActiveSupport.on_load(:active_job) do
  self.enqueue_after_transaction_commit = true
end

ActiveSupport.on_load(:action_mailer) do
  ActionMailer::MailDeliveryJob.prepend AccountTenanted
end

Rails.application.config.after_initialize do
  Turbo::Streams::ActionBroadcastJob.prepend AccountTenanted
  Turbo::Streams::BroadcastJob.prepend AccountTenanted
  Turbo::Streams::BroadcastStreamJob.prepend AccountTenanted
end
