# Refuses an email change for the directory reviewer's users, before any
# confirmation is sent (see User::ReviewerEmailAddressLock).
module Users::ReviewerEmailAddressLock
  extend ActiveSupport::Concern

  included do
    before_action :refuse_reviewer_email_address_change, only: %i[ new create ]
  end

  private
    def refuse_reviewer_email_address_change
      if @user.email_address_locked?
        error = "This email address can't be changed"

        respond_to do |format|
          format.html { redirect_to edit_user_path(@user), alert: error }
          format.json { render json: { error: error }, status: :forbidden }
        end
      end
    end
end
