module LoadBalancerRouting
  extend ActiveSupport::Concern

  included do
    before_action :set_target_header, :set_writer_header, :reproxy_when_stale, :reproxy_when_write_on_reader,
      if: :is_replicated_tenant?

    after_action :set_transaction_cookie, if: :is_replicated_tenant?
  end

  private
    def set_target_header
      response.headers["X-Kamal-Target"] = request.headers["X-Kamal-Target"]
    end

    def set_writer_header
      response.headers["X-Kamal-Writer"] = beamer_primary
      cookies["kamal-writer"] = { value: beamer_primary, path: Account.sole.slug }
    end

    def reproxy_when_stale
      reproxy_to_writer if request_stale?
    end

    def reproxy_when_write_on_reader
      if !safe_request? && !beamer_is_primary?
        reproxy_to_writer
      end
    end

    def request_stale?
      !beamer_is_primary? && required_transaction_not_yet_replicated?
    end

    def required_transaction_not_yet_replicated?
      client_txn = request.cookies["boxcar_last_transaction"]
      beamer_last_txn.present? && client_txn.present? && beamer_last_txn < client_txn
    end

    def set_transaction_cookie
      unless safe_request?
        if ApplicationRecord.current_tenant.present? && Account.sole.present?
          cookies["boxcar_last_transaction"] = { value: beamer_last_txn, path: Account.sole.slug }
        end
      end
    end

    def reproxy_to_writer
      uri = URI.parse(request.original_url)
      uri.port = nil
      uri.host = beamer_primary

      response.headers["X-Kamal-Reproxy-Location"] = uri.to_s
      head :see_other
    end

    def beamer_is_primary?
      @beamer_is_primary ||= ApplicationRecord.connection.beamer_primary?
    end

    def beamer_primary
      @beamer_primary ||= ApplicationRecord.connection.beamer_primary
    end

    def beamer_last_txn
      @beamer_last_txn ||= ApplicationRecord.connection.beamer_last_txn
    end

    def safe_request?
      request.get? || request.head?
    end

    def is_replicated_tenant?
      ApplicationRecord.current_tenant.present? && ApplicationRecord.connection_pool.db_config.adapter == "beamer"
    end
end
