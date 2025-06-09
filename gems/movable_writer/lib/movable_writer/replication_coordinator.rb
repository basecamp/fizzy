# frozen_string_literal: true

module MovableWriter
  class ReplicationCoordinator < ActiveSupport::ReplicationCoordinator::Base
    def fetch_active_zone
      MovableWriter.writer?
    end
  end
end
