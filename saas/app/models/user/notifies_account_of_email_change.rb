module User::NotifiesAccountOfEmailChange
  extend ActiveSupport::Concern

  included do
    after_update :notify_account_of_owner_change, if: :account_owner_changed?
  end

  private
    # Account owner changed when:
    # - The current owner changed their email
    # - A user just became the owner (ownership transfer)
    def account_owner_changed?
      owner? && identity && (saved_change_to_identity_id? || became_owner?)
    end

    def became_owner?
      saved_change_to_role? && role_before_last_save != "owner"
    end

    def notify_account_of_owner_change
      account.owner_email_changed
    end
end
