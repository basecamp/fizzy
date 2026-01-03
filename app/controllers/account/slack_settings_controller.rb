class Account::SlackSettingsController < ApplicationController
  before_action :ensure_admin

  def edit
    @setting = Current.account.slack_setting
  end

  def update
    Current.account.slack_setting.update!(setting_params)
    redirect_to edit_account_slack_setting_path, notice: "Slack settings updated"
  end

  private
    def setting_params
      params.expect(slack_setting: [
        :allow_messages,
        :allow_thread_replies,
        :allow_reactions
      ])
    end
end
