class ApplicationMailer < ActionMailer::Base
  default from: "The Fizzy team <support@37signals.com>"

  layout "mailer"
  append_view_path Rails.root.join("app/views/mailers")
  helper AvatarsHelper, HtmlHelper

  private
    def default_url_options
      if ApplicationRecord.current_tenant
        super.merge(script_name: Account.sole.slug)
      else
        super
      end
    end
end
