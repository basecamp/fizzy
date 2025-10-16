module TurboStreamsJobExtensions
  extend ActiveSupport::Concern

  class_methods do
    def render_format(format, **rendering)
      if ApplicationRecord.current_tenant
        script_name = "/#{ApplicationRecord.current_tenant}"
        ApplicationController.renderer.new(script_name: script_name).render(formats: [ format ], **rendering)
      else
        super
      end
    end
  end
end

Rails.application.config.after_initialize do
  Turbo::StreamsChannel.prepend TurboStreamsJobExtensions
end
