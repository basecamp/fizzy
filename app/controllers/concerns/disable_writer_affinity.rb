module DisableWriterAffinity
  extend ActiveSupport::Concern

  included do
    before_action :set_writer_affinity_opt_out_header
  end

  private
    def set_writer_affinity_opt_out_header
      response.headers["X-Writer-Affinity"] = "false"
    end
end
