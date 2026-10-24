# Looks up, fetches and persists metadata document clients for the authorization
# endpoint. Ported from bc3's Oauth::ClientMetadata::Resolver. Two modes, since
# GET requests read from a replica and mustn't write:
#
# - For read (the consent screen, a denial): a fresh row answers directly; a
#   stale or missing one is fetched into an unsaved client for the render.
#   Nothing persists, so denying never registers a client.
# - For intake (the authorization POST): fetches when stale or missing, and
#   creates or updates the row before any code is minted. A creation race
#   resolves through the unique index on client_id; a refresh rechecks under
#   the row lock.
#
# The token and revocation endpoints never resolve, they only look rows up: an
# outage at the client's site mustn't sign its users out, and the token
# endpoint is the hot path.
#
# A failed fetch aborts the authorization (the draft's answer); no failure is
# stored. Fetches are limited per person, per URL and per host, counted on
# attempt in Rails.cache. The counters fail open, as a flushed cache only resets
# them. Per person, because a shared budget is one anyone signed in can spend:
# a consent GET fetches without provisioning, so a script reloading it would
# refuse a client's first authorization to everyone. What bounds Fizzy's fetches
# overall is the fetcher's bulkhead and deadline, which answer a retryable 503
# rather than refusing the client. A provisioned client over budget keeps its
# stored document (see #throttled).
class Oauth::ClientMetadata::Resolver
  # Allows the consent render and the authorization POST their two fetches,
  # with room for retries.
  URL_ATTEMPT_LIMIT = 6
  URL_ATTEMPT_WINDOW = 1.minute

  # Bounds one person rotating paths on an allowlisted host.
  HOST_ATTEMPT_LIMIT = 60
  HOST_ATTEMPT_WINDOW = 1.hour

  Resolution = Data.define(:client, :outcome, :error_description) do
    def self.success(client) = new(client: client, outcome: :ok, error_description: nil)
    def self.failure(outcome, error_description) = new(client: nil, outcome: outcome, error_description: error_description)

    def success? = client.present?
  end

  def self.resolve_for_read(client_id, requester:)
    new(client_id, requester: requester).resolve(persist: false)
  end

  def self.resolve_for_intake(client_id, requester:)
    new(client_id, requester: requester).resolve(persist: true)
  end

  # requester is whoever is asking (the signed-in identity), whose fetch budget
  # the attempt spends.
  def initialize(client_id, requester:, fetcher: Oauth::ClientMetadata::Fetcher.new)
    @client_id = client_id
    @requester = requester
    @fetcher = fetcher
  end

  def resolve(persist:)
    if !Oauth::ClientMetadata::Url.valid?(@client_id)
      unknown_client(:invalid_url)
    elsif !Oauth::ClientMetadata.recognized?(@client_id)
      # Only an allowlisted host is ever fetched from. Anything else reads like
      # a typo: an unknown client.
      unknown_client(:unrecognized_host)
    elsif (row = Oauth::Client.find_presented(@client_id)) && !row.metadata_document?
      # A URL-shaped id names only a metadata document client. Resolving any
      # other row would let a document impersonate it.
      unknown_client(:conflicting_client)
    elsif row && fresh?(row)
      Resolution.success(row)
    elsif persist
      resolve_by_fetch(row) { |result| persist(row, result) }
    else
      resolve_by_fetch(row) { |result| build_in_memory(row, result) }
    end
  end

  private
    def fresh?(row)
      row.metadata_expires_at.present? && row.metadata_expires_at > Time.current
    end

    # Admission first: a saturated bulkhead is server pressure, and mustn't spend
    # the client's budgets.
    def resolve_by_fetch(row)
      if Oauth::ClientMetadata::Fetcher::Bulkhead.saturated?
        overloaded
      elsif !fetch_budget_available?
        throttled(row)
      else
        # What the conditional GET was made with, and the content clock as it
        # stood, for the compare-and-swap at persist time.
        @sent_etag = row&.metadata_etag
        @observed_fetched_at = row&.metadata_fetched_at

        result = @fetcher.fetch(@client_id, etag: @sent_etag)
        Rails.logger.info "OAuth client metadata fetch: #{result.outcome}"

        if result.outcome == :overloaded
          overloaded
        elsif result.failure?
          Resolution.failure(:fetch_failed, "Could not retrieve the client metadata document (#{result.outcome.to_s.humanize.downcase})")
        else
          yield result
        end
      end
    end

    def build_in_memory(row, result)
      if result.not_modified?
        Resolution.success(row)
      elsif attributes = document_attributes_for(result)
        client = row || Oauth::Client.new(provisioning_defaults)
        client.assign_attributes attributes.merge(metadata_fetched_at: Time.current, metadata_expires_at: result.expires_in.from_now)

        if client.valid?
          Resolution.success(client)
        else
          invalid_document
        end
      else
        invalid_document
      end
    end

    # A 304 needs a row to revalidate: the fetcher only answers one to the
    # If-None-Match that a stored row supplies.
    def persist(row, result)
      if result.not_modified?
        revalidate(row, result)
      elsif row
        update_row(row, result)
      else
        provision(result)
      end
    rescue ActiveRecord::RecordNotFound
      # The cleanup sweep removed the row between the lookup and the lock. A 200
      # carries the document to create it from again; a 304 carries nothing.
      if result.not_modified?
        overloaded
      else
        provision(result)
      end
    end

    # A 304 confirms only the document the ETag we sent named. Applied only while
    # the stored ETag still matches it, so a racing 200 that stored a newer
    # document keeps its own freshness. Never moves fetched_at: no content came.
    def revalidate(row, result)
      row.with_lock do
        if row.metadata_etag == @sent_etag
          row.metadata_etag = result.etag if result.etag.present?
          row.metadata_expires_at = result.expires_in.from_now
          row.save!
        end
      end

      Resolution.success(row)
    end

    def update_row(row, result)
      if attributes = document_attributes_for(result)
        row.with_lock do
          # Compare-and-swap on the content clock: another 200 that moved
          # fetched_at while we fetched won.
          if row.metadata_fetched_at == @observed_fetched_at
            row.update! attributes.merge(metadata_fetched_at: Time.current, metadata_expires_at: result.expires_in.from_now, metadata_etag: result.etag)
          end
        end

        Resolution.success(row)
      else
        invalid_document
      end
    rescue ActiveRecord::RecordInvalid
      invalid_document
    end

    def provision(result)
      if attributes = document_attributes_for(result)
        client = Oauth::Client.create! \
          provisioning_defaults.merge(attributes).merge(metadata_fetched_at: Time.current, metadata_expires_at: result.expires_in.from_now, metadata_etag: result.etag)

        Rails.logger.info "OAuth client provisioned from its metadata document"
        Resolution.success(client)
      else
        invalid_document
      end
    rescue ActiveRecord::RecordNotUnique
      adopt_creation_race_winner
    rescue ActiveRecord::RecordInvalid => error
      # A taken client_id is the same lost race, caught by the uniqueness
      # validation's query instead of the index.
      if error.record.errors.of_kind?(:client_id, :taken)
        adopt_creation_race_winner
      else
        invalid_document
      end
    end

    # The winner gets the same scrutiny resolve gives a looked-up row.
    def adopt_creation_race_winner
      if (winner = Oauth::Client.find_presented(@client_id))&.metadata_document?
        Resolution.success(winner)
      else
        unknown_client(:conflicting_client)
      end
    end

    def document_attributes_for(result)
      document = Oauth::ClientMetadata::Document.parse(result.body, client_id: @client_id)

      if document.valid?
        document.attributes
      else
        @document_error = document.error_description
        nil
      end
    end

    def provisioning_defaults
      { client_id: @client_id, token_endpoint_auth_method: "none", trusted: false, dynamically_registered: false, client_id_metadata_document: true }
    end

    def fetch_budget_available?
      within_budget?("oauth:client_metadata:#{requester_key}:url:#{Digest::SHA256.hexdigest(@client_id)}", URL_ATTEMPT_LIMIT, URL_ATTEMPT_WINDOW) && \
        within_budget?("oauth:client_metadata:#{requester_key}:host:#{Oauth::ClientMetadata::Url.host(@client_id).downcase}", HOST_ATTEMPT_LIMIT, HOST_ATTEMPT_WINDOW)
    end

    def requester_key
      @requester&.id || "anonymous"
    end

    def within_budget?(key, limit, window)
      count = increment_counter(key, window)
      count.nil? || count <= limit
    end

    def increment_counter(key, window)
      Rails.cache.increment(key, 1, expires_in: window)
    rescue StandardError
      nil
    end

    # The budgets bound how often Fizzy fetches, and anyone signed in can spend
    # them, on any URL of an allowlisted host. So a client already provisioned
    # isn't refused for it: its stored document, valid when fetched, stands
    # until a fetch is allowed again. Only a client never seen waits.
    def throttled(row)
      if row
        Resolution.success(row)
      else
        Resolution.failure(:throttled, "Metadata fetch attempts are temporarily limited for this client")
      end
    end

    def unknown_client(outcome)
      Resolution.failure(outcome, "Unknown client")
    end

    def invalid_document
      Resolution.failure(:invalid_document, @document_error || "Client metadata document is invalid")
    end

    def overloaded
      Resolution.failure(:overloaded, "The authorization server is briefly over capacity")
    end
end
