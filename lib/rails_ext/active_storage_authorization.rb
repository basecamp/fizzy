# HackerOne #3943339: never serve a blob inline with a media type a browser or
# Turbo will execute as markup. An exact-string list is too narrow: Turbo's
# frame renderer treats a whole family of declared types as HTML — its
# FetchResponse#isHTML test is /^(?:text\/([^\s;,]+\b)?html|application\/xhtml\+xml)\b/,
# which matches non-canonical forms such as "text/x-html", "text/html+foo",
# "text/vnd.turbo-stream.html", and "application/xhtml+xml+foo" that an exact
# list misses — and Content-Disposition does not stop Turbo's fetch. This regex
# mirrors that matcher (case-insensitively, so a "TEXT/HTML" echo is caught too)
# and adds the browser-scriptable SVG/XML types, so every such blob is forced to
# application/octet-stream. Parameterized types like "text/html;charset=utf-8"
# and malformed ones like "text/html,foo" are covered by the leading essence
# match ending at a word boundary.
ActiveStorage::DANGEROUS_INLINE_MEDIA_TYPE = %r{
  \A(?:
      text/(?:[^\s;,]+\b)?html
    | application/xhtml\+xml
    | image/svg\+xml
    | application/xml
    | text/xml
  )\b
}xi

ActiveSupport.on_load :active_storage_blob do
  def accessible_to?(user)
    attached = attachments.includes(:record).to_a

    if attached.any?
      attached.any? { |attachment| attachment.accessible_to?(user) }
    else
      unattached_accessible_to?(user)
    end
  end

  def publicly_accessible?
    attachments.includes(:record).any? { |attachment| attachment.publicly_accessible? }
  end

  private
    # An unattached blob is only meant to be viewable in the brief window
    # between direct upload and attachment (commit 196d685f8d). Scope that
    # fail-open to a principal inside the blob's own account, so an attacker's
    # deliberately-unattached blob is not authorized to unrelated identities in
    # other accounts (HackerOne #3943339). Cross-account access falls through to
    # the forbidden path.
    def unattached_accessible_to?(user)
      user.present? && account_id == user.account_id
    end

    def forcibly_serve_as_binary?
      super || dangerous_inline_media_type?
    end

    def dangerous_inline_media_type?
      ActiveStorage::DANGEROUS_INLINE_MEDIA_TYPE.match?(content_type.to_s.strip)
    end
end

ActiveSupport.on_load :active_storage_attachment do
  def accessible_to?(user)
    record.try(:accessible_to?, user)
  end

  def publicly_accessible?
    record.try(:publicly_accessible?)
  end
end

Rails.application.config.to_prepare do
  module ActiveStorage::Authorize
    extend ActiveSupport::Concern

    include Authentication

    included do
      # Ensure require_authentication runs after set_blob.
      skip_before_action :require_authentication
      before_action :require_authentication, :ensure_accessible, unless: :publicly_accessible_blob?
    end

    private
      def bearer_token_authenticatable_request?
        true
      end

      def publicly_accessible_blob?
        @blob.publicly_accessible?
      end

      def ensure_accessible
        unless @blob.accessible_to?(Current.user)
          head :forbidden
        end
      end

      def http_cache_forever(public: false, **options, &block)
        super(public: public && publicly_accessible_blob?, **options, &block)
      end
  end

  ActiveStorage::Blobs::RedirectController.include ActiveStorage::Authorize
  ActiveStorage::Blobs::ProxyController.include ActiveStorage::Authorize
  ActiveStorage::Representations::RedirectController.include ActiveStorage::Authorize
  ActiveStorage::Representations::ProxyController.include ActiveStorage::Authorize
end
