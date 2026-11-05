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

  # set_representation is a before_action on Representations::BaseController that runs
  # @blob.representation(...).processed — the ffmpeg/mutool/libvips parser. Because it is
  # registered on the parent, it precedes the authorization callbacks this concern appends,
  # so the parser would otherwise run against an unauthorized (or anonymous) request before
  # ensure_accessible is ever consulted. Re-append set_representation on each representations
  # controller so it runs after require_authentication and ensure_accessible.
  [ ActiveStorage::Representations::RedirectController, ActiveStorage::Representations::ProxyController ].each do |controller|
    controller.include ActiveStorage::Authorize
    controller.skip_before_action :set_representation
    controller.before_action :set_representation
  end
end
