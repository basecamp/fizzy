require "net/http"

# Fetches a client metadata document, hardened for a URL someone else chose.
# Ported from bc3's Oauth::ClientMetadata::Fetcher. Layers, outermost first:
#
# 1. Bulkhead: at most Bulkhead::LIMIT fetches in flight per process.
#    Saturation is server pressure, not a bad document: it answers :overloaded
#    (503 upstream) and charges no budget.
# 2. One deadline, DNS to final byte. A monotonic instant drives the in-band
#    checks, and a Timeout wrap expiring at the same instant backstops what they
#    can't see: Surfguard's DNS wait, TCP open, the TLS handshake. FetchOverrun
#    is deliberately not a Timeout::Error, since Resolv rescues ResolvTimeout (a
#    Timeout::Error) and would swallow the interrupt.
# 3. Connect discipline: Surfguard resolves the host once under its strict
#    :iana_special_use policy, which refuses private, loopback and link-local
#    addresses and every IANA special-purpose range (NAT64, AMT and AS112
#    included, which the default policy admits). An answer set mixing public and
#    blocked addresses is refused whole. The connection is pinned to the address
#    admitted (http.ipaddr), so a second lookup can't rebind it.
#    The proxy is an explicit nil, since Net::HTTP otherwise reads HTTP_PROXY
#    and would send the request somewhere else. TLS verifies the peer against
#    the URL's host, which also rides SNI and the Host header. max_retries is 0,
#    since the default resends idempotent requests and doubles the worst case.
# 4. BudgetedIO: every byte Net::HTTP reads (status line, headers, chunk framing,
#    body) goes through one buffered read, so one override bounds the wire bytes
#    and re-arms the read timeout from the remaining deadline before each fill.
#    A drip-feed can't reset a fixed window, and a huge header block dies at
#    MAX_WIRE_BYTES instead of being buffered and parsed.
# 5. Body: identity transfer only. Asking for it turns off Net::HTTP's
#    transparent gunzip, so the size cap counts wire bytes, and any other
#    encoding is refused.
#
# No redirects are followed (the document must live at the client_id URL), and
# only application/json or application/*+json is read. A stored ETag makes the
# request conditional.
#
# Answers a Result rather than raising: every outcome is one bounded label.
# Freshness arithmetic (max-age or Expires, inside our own floor and ceiling)
# lives here too, so callers store an expiry.
class Oauth::ClientMetadata::Fetcher
  TOTAL_TIMEOUT = 3.seconds
  MAX_BODY_SIZE = 5.kilobytes

  # Status line, headers, chunk framing, the 5KB body and some slack. Checked
  # after each buffer fill, and one fill reads up to Net::BufferedIO::BUFSIZE
  # (16KiB), so the true bound is MAX_WIRE_BYTES + BUFSIZE.
  MAX_WIRE_BYTES = 16.kilobytes

  # Our bounds around the document's caching headers: it can't force a fetch per
  # authorization (MIN_TTL), or pin itself for a week (MAX_TTL). Silence means
  # DEFAULT_TTL.
  DEFAULT_TTL = 1.hour
  MIN_TTL = 5.minutes
  MAX_TTL = 24.hours

  # The oauth_clients.metadata_etag column's width. An ETag that doesn't fit is
  # dropped, not truncated, since a truncated one would never match again.
  MAX_ETAG_LENGTH = 191

  USER_AGENT = "Fizzy-OAuth/1.0 (client metadata)"

  # In-band budget refusals. StandardError on purpose; see layer 2.
  class DeadlineExceeded < StandardError; end
  class WireBudgetExceeded < StandardError; end
  class FetchOverrun < StandardError; end

  Result = Data.define(:outcome, :body, :etag, :expires_in) do
    def self.failure(outcome) = new(outcome: outcome, body: nil, etag: nil, expires_in: nil)

    def success? = outcome == :ok
    def not_modified? = outcome == :not_modified
    def failure? = !success? && !not_modified?
  end

  # A per-process ceiling on concurrent fetches.
  class Bulkhead
    Saturated = Class.new(StandardError)

    LIMIT = 2

    @in_flight = 0
    @lock = Mutex.new

    class << self
      def acquire
        @lock.synchronize do
          raise Saturated if @in_flight >= LIMIT
          @in_flight += 1
        end

        begin
          yield
        ensure
          @lock.synchronize { @in_flight -= 1 }
        end
      end

      # Advisory, for callers that charge budgets before fetching: an attempt
      # the bulkhead would refuse mustn't spend them. acquire still enforces.
      def saturated?
        @lock.synchronize { @in_flight >= LIMIT }
      end
    end
  end

  def initialize(cert_store: nil, total_timeout: TOTAL_TIMEOUT)
    @cert_store = cert_store
    @total_timeout = total_timeout
  end

  # Fetches the document at a valid metadata document URL (callers validate it
  # with Oauth::ClientMetadata::Url first).
  def fetch(url, etag: nil)
    uri = URI.parse(url)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @total_timeout

    Bulkhead.acquire do
      Timeout.timeout(remaining_time(deadline), FetchOverrun) do
        if address = Surfguard.resolve_public_ip(uri.to_s, policy: :iana_special_use)
          perform_request(uri, address, etag: etag, deadline: deadline)
        else
          Result.failure(:blocked_address)
        end
      end
    end
  rescue Bulkhead::Saturated
    Result.failure(:overloaded)
  rescue FetchOverrun, DeadlineExceeded, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
    Result.failure(:timeout)
  rescue Surfguard::Unresolvable, Resolv::ResolvError
    Result.failure(:unresolvable)
  rescue WireBudgetExceeded
    Result.failure(:too_large)
  rescue OpenSSL::SSL::SSLError
    Result.failure(:tls_failed)
  rescue SystemCallError, SocketError, IOError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
    # The last three are a hostile server feeding the parser garbage: a typed
    # refusal, never a 500.
    Result.failure(:connection_failed)
  end

  private
    # Net::HTTP#connect assigns @socket last, with nothing read yet, then calls
    # the empty private on_connect hook, where the budgeted reader goes in.
    module GuardedConnection
      attr_accessor :deadline, :wire_budget

      private
        def on_connect
          @socket = BudgetedIO.new(@socket.io,
            deadline: deadline, wire_budget: wire_budget,
            read_timeout: @socket.read_timeout,
            write_timeout: @socket.write_timeout,
            continue_timeout: @socket.continue_timeout,
            debug_output: @socket.debug_output)
        end
    end

    # Built on first use, not at load time: a static subclass would freeze its
    # superclass at boot, before WebMock swaps Net::HTTP out in tests, so every
    # stubbed fetch would open a real socket.
    def self.connection_class
      @connection_class ||= Class.new(Net::HTTP) { include GuardedConnection }
    end

    # rbuf_fill is the one funnel both readuntil (status line, headers) and read
    # (body) loop on.
    class BudgetedIO < Net::BufferedIO
      def initialize(io, deadline:, wire_budget:, **options)
        super(io, **options)
        @deadline = deadline
        @wire_budget = wire_budget
        @wire_bytes = 0
      end

      private
        def rbuf_fill
          self.read_timeout = remaining_time
          unconsumed = rbuf_size
          super
          @wire_bytes += rbuf_size - unconsumed

          raise WireBudgetExceeded if @wire_bytes > @wire_budget
        end

        def remaining_time
          remaining = @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise DeadlineExceeded if remaining <= 0

          remaining
        end
    end

    def perform_request(uri, address, etag:, deadline:)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = USER_AGENT
      # Setting this explicitly also turns off transparent decoding, so every
      # size bound measures wire bytes.
      request["Accept-Encoding"] = "identity"
      request["If-None-Match"] = etag if etag.present?

      http = build_connection(uri, address, deadline: deadline)
      result = nil

      http.start do
        http.request(request) do |response|
          result = judge_response(response, sent_etag: etag, deadline: deadline)
        end
      end

      result
    end

    def build_connection(uri, address, deadline:)
      # An explicit nil proxy: the third argument defaults to the environment's.
      self.class.connection_class.new(uri.hostname, uri.port, nil).tap do |http|
        http.deadline = deadline
        http.wire_budget = MAX_WIRE_BYTES
        http.ipaddr = address
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.cert_store = @cert_store if @cert_store
        http.max_retries = 0

        timeout = remaining_time(deadline)
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.write_timeout = timeout
      end
    end

    def judge_response(response, sent_etag:, deadline:)
      case response
      when Net::HTTPOK
        read_document(response, deadline: deadline)
      when Net::HTTPNotModified
        # Meaningful only as the answer to an If-None-Match we sent. An ETag on
        # the 304 itself updates the validator (RFC 9111 §4.3.4).
        if sent_etag.present?
          Result.new(outcome: :not_modified, body: nil, etag: storable_etag(response), expires_in: freshness_lifetime(response))
        else
          Result.failure(:unexpected_not_modified)
        end
      when Net::HTTPRedirection
        Result.failure(:redirect)
      else
        Result.failure(:http_error)
      end
    end

    def read_document(response, deadline:)
      if !identity_encoded?(response)
        Result.failure(:wrong_content_encoding)
      elsif response.content_length.to_i > MAX_BODY_SIZE
        Result.failure(:too_large)
      elsif !json_content_type?(response)
        Result.failure(:wrong_content_type)
      elsif body = size_restricted_body(response, deadline: deadline)
        Result.new(outcome: :ok, body: body, etag: storable_etag(response), expires_in: freshness_lifetime(response))
      else
        Result.failure(:too_large)
      end
    end

    def identity_encoded?(response)
      encoding = response["Content-Encoding"]
      encoding.blank? || encoding.strip.casecmp?("identity")
    end

    # application/json, or the +json structured syntax suffix the draft permits.
    def json_content_type?(response)
      content_type = response.content_type.to_s.downcase
      content_type == "application/json" || \
        (content_type.start_with?("application/") && content_type.end_with?("+json"))
    end

    # The Content-Length check bounds honest responses; this bounds the ones
    # that lie, and holds the deadline through a slow-dripped body. The rest of
    # an oversized body is left unread, and the connection closes with it.
    def size_restricted_body(response, deadline:)
      body = +""
      oversized = false

      response.read_body do |chunk|
        raise DeadlineExceeded if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        if oversized || body.bytesize + chunk.bytesize > MAX_BODY_SIZE
          oversized = true
          break
        else
          body << chunk
        end
      end

      body unless oversized
    end

    # Stored verbatim, weak validators included, or dropped when it doesn't fit
    # the column or isn't valid UTF-8 (which would 500 at save rather than fail
    # as a typed result).
    def storable_etag(response)
      etag = response["ETag"]
      etag if etag.present? && etag.length <= MAX_ETAG_LENGTH && etag.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end

    # RFC 9111 freshness inside our own bounds: max-age less Age, else Expires
    # less Date less Age, else DEFAULT_TTL. no-store, no-cache, zero and
    # negative all floor at MIN_TTL: how often we fetch is ours to set.
    def freshness_lifetime(response)
      cache_control = parse_cache_control(response["Cache-Control"])

      lifetime = if cache_control.key?("no-store") || cache_control.key?("no-cache")
        0
      elsif cache_control.key?("max-age")
        cache_control["max-age"].to_i - response["Age"].to_i
      elsif response["Expires"].present?
        expires_lifetime(response)
      else
        DEFAULT_TTL.to_i
      end

      lifetime.clamp(MIN_TTL.to_i, MAX_TTL.to_i).seconds
    end

    def expires_lifetime(response)
      expires = Time.httpdate(response["Expires"])
      date = response["Date"].present? ? Time.httpdate(response["Date"]) : Time.current
      (expires - date).to_i - response["Age"].to_i
    rescue ArgumentError
      # An unparseable Expires is already stale, so the floor applies.
      0
    end

    def parse_cache_control(header)
      header.to_s.downcase.split(",").to_h do |directive|
        name, value = directive.strip.split("=", 2)
        [ name, value ]
      end
    end

    def remaining_time(deadline)
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise DeadlineExceeded if remaining <= 0

      remaining
    end
end
