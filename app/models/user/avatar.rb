module User::Avatar
  extend ActiveSupport::Concern

  ALLOWED_AVATAR_CONTENT_TYPES = %w[ image/jpeg image/png image/gif image/webp ].freeze

  included do
    has_one_attached :avatar do |attachable|
      attachable.variant :thumb, resize_to_fill: [ 256, 256 ], process: :immediately
    end

    validate :avatar_content_type_allowed
  end

  def avatar_thumbnail
    avatar.variable? ? avatar.variant(:thumb) : avatar
  end

  private
    def avatar_content_type_allowed
      if avatar.attached? && !ALLOWED_AVATAR_CONTENT_TYPES.include?(avatar.content_type)
        errors.add(:avatar, "must be a JPEG, PNG, GIF, or WebP image")
      end
    end
end
