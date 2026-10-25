# Refuses to deactivate the directory reviewer's users from the app, whoever
# asks. Deactivating a user clears its identity, so the account would drop out
# of the reviewer's accounts, and `saas:reviewer_sign_in:sign_out` would then
# neither reset that account's join code nor list its members for the
# after-review check. Operators who mean to remove the reviewer do it from a
# console.
module Users::ReviewerMembershipLock
  extend ActiveSupport::Concern

  included do
    before_action :refuse_reviewer_deactivation, only: %i[ destroy ]
  end

  private
    def refuse_reviewer_deactivation
      if Identity::ReviewerSignIn.reviewer?(@user.identity)
        error = "This person can't be removed"

        respond_to do |format|
          format.html { redirect_to account_settings_path, alert: error }
          format.json { render json: { error: error }, status: :forbidden }
        end
      end
    end
end
