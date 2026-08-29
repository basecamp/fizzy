module Identity::Joinable
  extend ActiveSupport::Concern

  # Enables user reactivation when rejoining an account after deactivation.
  #
  # Relies on User#deactivate preserving the identity link (no `identity: nil`).
  # When a deactivated user rejoins, find_or_create_by! finds their existing
  # record and the reactivation block restores them to active status.
  #
  # Return value semantics for JoinCode#redeem_if:
  #   - true:  new user created (increments usage count)
  #   - false: existing user found (active or reactivated, no increment)

  def join(account, **attributes)
    attributes[:name] ||= email_address

    transaction do
      user = account.users.find_or_create_by!(identity: self) do |u|
        u.assign_attributes(attributes)
      end

      # Reactivate if found but inactive. New users get board access via
      # after_create_commit callback, but reactivated users need it manually
      # since update! doesn't trigger create callbacks.
      unless user.previously_new_record? || user.active?
        user.update!(active: true)
        user.send(:grant_access_to_boards)
      end

      user.previously_new_record?
    end
  end
end
