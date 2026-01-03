class Account::GithubSettingsController < ApplicationController
  before_action :ensure_admin

  def edit
    @setting = Current.account.github_setting
  end

  def update
    Current.account.github_setting.update!(setting_params)
    redirect_to edit_account_github_setting_path, notice: "GitHub settings updated"
  end

  private
    def setting_params
      params.expect(github_setting: [
        :allow_pull_requests,
        :allow_issues,
        :allow_comments,
        :allow_reviews
      ])
    end
end
