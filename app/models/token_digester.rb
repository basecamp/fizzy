# Bearer credentials (access tokens, refresh tokens, client secrets) are
# stored as HMAC-SHA256(pepper, raw) digests, never as the raw value, so a
# copy of the database doesn't hand anyone a working credential. A lookup
# digests what it's given and finds the row by that digest.
#
# Byte-compatible with bc3's Oauth::TokenDigester: lowercase hex of
# HMAC-SHA256 under the pepper, nothing else.
#
# A digest may carry a version prefix, "<n>$<hex>", so the pepper can be
# rotated later without a flag day: digests made under a new pepper carry its
# version while older rows keep theirs, and lookups try every version still
# in service. A bare digest is version 1. Only version 1 exists today.
#
# The pepper:
#
# - SaaS deployments read it from OAUTH_TOKEN_PEPPER, and refuse to boot
#   without it (config/initializers/token_digester.rb). The name mirrors
#   bc3's credentials.oauth.token_pepper; personal access tokens are digested
#   under it too. Beta reads production's database, so beta and production
#   must share one pepper: saas/.kamal/secrets.beta fetches production's
#   field rather than keeping a copy that could drift.
# - Elsewhere OAUTH_TOKEN_PEPPER is used when set, and otherwise a key is
#   derived from secret_key_base. On a self-hosted install, then, changing
#   SECRET_KEY_BASE invalidates every personal access token and OAuth grant.
#
# Changing the pepper invalidates every stored digest, so it MUST NOT change
# except through a versioned rotation.
module TokenDigester
  extend self

  class MissingPepper < StandardError; end

  CURRENT_VERSION = 1
  VERSION_SEPARATOR = "$"
  MINIMUM_PEPPER_LENGTH = 32

  def digest(raw, version: CURRENT_VERSION)
    hex = OpenSSL::HMAC.hexdigest("SHA256", peppers.fetch(version), raw)
    version == 1 ? hex : "#{version}#{VERSION_SEPARATOR}#{hex}"
  end

  # Every digest a stored credential might carry, one per pepper version in
  # service, for an indexed lookup: where(token_digest: TokenDigester.digests(raw)).
  def digests(raw)
    peppers.keys.map { |version| digest(raw, version: version) }
  end

  def verify(raw, stored_digest)
    if raw.is_a?(String) && raw.present? && stored_digest.is_a?(String) && peppers.key?(version = version_of(stored_digest))
      ActiveSupport::SecurityUtils.secure_compare(digest(raw, version: version), stored_digest)
    else
      false
    end
  end

  def version_of(stored_digest)
    if stored_digest.include?(VERSION_SEPARATOR)
      Integer(stored_digest.split(VERSION_SEPARATOR, 2).first, 10, exception: false)
    else
      1
    end
  end

  # Raises unless a usable pepper is configured. Run at boot, so a deploy
  # missing the secret fails before it serves a request, rather than at the
  # first lookup, and never by quietly digesting under another key.
  def verify_pepper!
    peppers
    true
  end

  def pepper_required?
    Fizzy.saas? && !Rails.env.local?
  end

  private
    def peppers
      @peppers ||= { 1 => configured_pepper(ENV["OAUTH_TOKEN_PEPPER"], required: pepper_required?) }
    end

    def configured_pepper(value, required:)
      if value.present?
        if value.length < MINIMUM_PEPPER_LENGTH
          raise MissingPepper, "OAUTH_TOKEN_PEPPER must be at least #{MINIMUM_PEPPER_LENGTH} characters; generate one with bin/rails secret"
        else
          value
        end
      elsif required
        raise MissingPepper, "OAUTH_TOKEN_PEPPER is required in this environment. Refusing to fall back to a key derived from secret_key_base, which would digest under a different key than every token already stored"
      else
        Rails.application.key_generator.generate_key("token_digest_pepper", 32)
      end
    end
end
