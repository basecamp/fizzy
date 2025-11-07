class Signup::CompletionsController < ApplicationController
  require_untenanted_access

  layout "public"

  def new
    @signup = Signup.new(signup_params)

    cookies["kamal-writer"] = { value: closest_writer, path: @signup.tenant } if closest_writer
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.complete
      redirect_to landing_url(script_name: "/#{@signup.tenant}")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def signup_params
      params.expect(signup: %i[ full_name account_name membership_id ]).with_defaults(identity: Current.identity)
    end

    def closest_writer
      zone = ENV["SOLID_QUEUE_ZONE"]

      if zone
        primary_file = Rails.root.join("storage", ".beamer", "zones", zone, "NODE")
        primary_file.read if primary_file.exists?
      end
    end
end
