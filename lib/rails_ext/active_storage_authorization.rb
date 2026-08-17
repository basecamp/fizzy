# HackerOne #3943339: never serve HTML/XML/SVG blobs inline as their declared
# content type. Parameterized MIME types such as "text/html;charset=utf-8" slip
# past Active Storage's exact-string binary list, so these must be forced to
# binary after normalizing the media type. (SVG/XML are scriptable when rendered
# inline same-origin, so they are neutralized here as well.)
ActiveStorage::DANGEROUS_INLINE_MEDIA_TYPES = %w[
  text/html application/xhtml+xml image/svg+xml application/xml text/xml
].freeze

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
      ActiveStorage::DANGEROUS_INLINE_MEDIA_TYPES.include?(media_type_for_serving)
    end

    def media_type_for_serving
      content_type.to_s.split(";").first.to_s.strip.downcase
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
