# RFC 8693 token delegation (hosted plan, phase C): the hosted Fizzy MCP
# server exchanges the token a person's MCP client presented to it (an
# audienced grant, which Fizzy's API refuses) for a short-lived, account-bound
# API token that acts for the same person. Ported from bc3's
# Oauth::TokenDelegation, without the DPoP, agent and entitlement checks bc3
# has and Fizzy doesn't; the error codes are bc3's
# (doc/oauth/mcp_token_delegation.md §4), so the server's terminal and infra
# handling is shared code.
#
# Invariants:
# - Audience: the subject's own audience must equal the resource the client
#   fronts. That one check refuses Fizzy's own grants, personal access tokens
#   and delegated tokens alike (they carry no audience), so delegation can't
#   chain.
# - Account: the subject must be bound to one account, and the minted token
#   is bound to the same one.
# - Lifecycle: the minted token records the subject grant. Ending that grant
#   sweeps it, and every API request checks the grant is still there.
# - Scope derives from the subject and only ever narrows.
# - No refresh. The token lives at most TTL_CAP, and never past the subject's
#   own expiry; the server exchanges again when it lapses.
# - A refused subject answers invalid_grant, not RFC 8693 §2.2.2's
#   invalid_request, as bc3 does: the server tells a dead subject (terminal,
#   reconnect) from a malformed request (its own bug).
#
#   delegation = Oauth::TokenDelegation.new(client:, subject_token:, api_resource:, requested_scope:, resource:)
#   delegation.validate!
#   access_token = delegation.mint!
class Oauth::TokenDelegation
  GRANT_TYPE = "urn:ietf:params:oauth:grant-type:token-exchange"
  ACCESS_TOKEN_TYPE = "urn:ietf:params:oauth:token-type:access_token"

  # Five minutes at most, whatever else is configured: a token the server
  # holds in memory stops working within this long of its grant ending,
  # even if the sweep and the use-time check both missed it.
  TTL_CAP = 300.seconds

  # A subject with less left than this is refused as expired, rather than
  # traded for a token that would die in flight: the lock, insert and
  # response could floor its expires_in to 0, which the server can't use and
  # retries as an outage. Refused, the server's client refreshes the subject
  # instead. Ten seconds is the skew the server retires tokens early by.
  MINIMUM_SUBJECT_LIFETIME = 10.seconds

  # A refusal carries the OAuth error the endpoint answers with.
  class Refusal < StandardError
    attr_reader :error

    def initialize(error, description)
      @error = error
      super(description)
    end
  end

  attr_reader :client, :subject_token, :requested_scope, :resource, :api_resource, :subject, :permission

  # Delegation is on only where Fizzy is configured with a protected resource
  # to issue grants for (Oauth.mcp_resources). Off on every install that
  # never sets one.
  def self.enabled?
    Oauth.mcp_resources.any?
  end

  # Whether a token endpoint request asks for this grant. A body that
  # doesn't parse asks for nothing here, and the token endpoint answers it.
  def self.request?(request)
    request.request_parameters["grant_type"] == GRANT_TYPE
  rescue ActionDispatch::Http::Parameters::ParseError
    false
  end

  # api_resource says whether a resource identifier names Fizzy's own API, the
  # one resource a minted token is for, in any form the server advertises it.
  def initialize(client:, subject_token:, api_resource:, requested_scope: nil, resource: nil)
    @client = client
    @api_resource = api_resource
    @subject_token = subject_token
    @requested_scope = requested_scope
    @resource = resource
  end

  # Raises a Refusal in the endpoint's pinned order: client eligibility, then
  # the subject, then the resource, then the scope.
  def validate!
    unless client.delegation_client?
      raise Refusal.new("unauthorized_client", "Client not configured for token delegation")
    end

    unless client.confidential?
      raise Refusal.new("unauthorized_client", "Token delegation requires a confidential client")
    end

    @subject = Identity::AccessToken.oauth.find_by_raw_token(subject_token)
    judge_subject

    validate_resource
    @permission = resolve_permission

    self
  end

  # The one API token this exchange issues, under two locks, each judged
  # again once held. The client's comes first, as Oauth::Client#redeem takes
  # it before issuing a grant and destroying the client takes it before
  # cascading its tokens, so a token can't land after that cascade. Then the
  # subject grant's, which revoking it takes before sweeping its delegated
  # tokens, so an exchange racing a revocation is either refused or inserted
  # first and swept with it. Scope is resolved again too, so a refresh that
  # narrowed the grant meanwhile narrows the token, or refuses a request for
  # what the grant no longer holds. The subject is found again by the presented
  # token, not its row: a refresh rotates the token in place, so a token
  # rotated away meanwhile finds nothing and is refused. Nothing takes the two
  # locks in the other order.
  def mint!
    Identity::AccessToken.transaction do
      # The locked row is the client judged from here on, so a change to its
      # scopes or resource that committed while this waited for the lock
      # governs the token it mints.
      @client = Oauth::Client.lock.find_by(id: client.id)
      unless client&.delegation_client?
        raise Refusal.new("unauthorized_client", "Client not configured for token delegation")
      end

      @subject = Identity::AccessToken.lock.oauth.find_by_raw_token(subject_token)
      judge_subject
      @permission = resolve_permission

      Identity::AccessToken.create! \
        identity_id: subject.identity_id,
        account_id: subject.account_id,
        oauth_client: client,
        delegated_from: subject,
        permission: permission,
        expires_at: [ TTL_CAP.from_now, subject.expires_at ].min
    end
  end

  def scope
    Oauth.canonical_scope(permission)
  end

  private
    def judge_subject
      if (reason = subject_refusal_reason)
        refuse_subject reason
      elsif !subject.audienced? || !client.fronts?(subject.audience)
        raise Refusal.new("invalid_grant", "Subject token is not audienced to this client's protected resource")
      elsif !subject.account_bound?
        raise Refusal.new("invalid_grant", "Subject token is not account-bound")
      elsif !membership_live?
        raise Refusal.new("invalid_grant", "Subject token's user no longer has account access")
      end
    end

    # Why a subject is "not valid", for the log alone: the answer is the one
    # description whatever the reason, so a caller learns nothing about a
    # token it presents.
    def subject_refusal_reason
      if subject.nil?
        "unknown"
      elsif subject.delegated?
        "delegated"
      elsif subject.expires_at.nil? || subject.expires_at < MINIMUM_SUBJECT_LIFETIME.from_now
        "expired"
      elsif subject.lapsed?
        "lapsed"
      elsif !subject.honored?
        "not_honored"
      end
    end

    def refuse_subject(reason)
      Rails.logger.info "[OAuth] Token delegation subject refused: " \
        "#{{ client: client.client_id, reason: reason, access_token_id: subject&.id, identity_id: subject&.identity_id }.compact.inspect}"

      raise Refusal.new("invalid_grant", "Subject token is not valid")
    end

    # The exchange answers out of process, so success must mean the minted
    # token will work: a person who has left the account, or an account that
    # has gone, earns a refusal rather than a dead credential.
    def membership_live?
      user = User.find_by(identity_id: subject.identity_id, account_id: subject.account_id)
      user&.active? && user.account.active?
    end

    # RFC 8707: a resource names where the minted token will be used. Fizzy's
    # API is the only place it can be, so its identifier, as the protected
    # resource metadata advertises it or as the issuer, is accepted like an
    # absent parameter, and anything else is refused.
    def validate_resource
      if resource.present? && !api_resource.call(resource)
        raise Refusal.new("invalid_target", "resource does not match the subject token's account")
      end
    end

    # Strict, as bc3's is: an unknown, disallowed or wider scope refuses the
    # whole request rather than silently narrowing it. The ceiling is the
    # subject's own grant.
    def resolve_permission
      granted = Oauth.canonical_scope(subject.permission).split
      requested = requested_scope.nil? ? granted : requested_scope.to_s.split

      requested.each do |scope|
        if !scope.in?(%w[ read write ])
          raise Refusal.new("invalid_scope", "Unknown scope: #{scope}")
        elsif !client.scopes.include?(scope)
          raise Refusal.new("invalid_scope", "Scope '#{scope}' not allowed for this client")
        end
      end

      if requested.empty?
        raise Refusal.new("invalid_scope", "Scope must include 'read' or 'write' for API access")
      elsif (requested - granted).any?
        raise Refusal.new("invalid_scope", "Scope exceeds the subject token's scope")
      end

      requested.include?("write") ? "write" : "read"
    end
end
