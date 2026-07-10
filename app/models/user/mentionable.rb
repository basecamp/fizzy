module User::Mentionable
  extend ActiveSupport::Concern

  included do
    has_many :mentions, dependent: :destroy, inverse_of: :mentionee

    # Need to set in the included block so that it overrides Action Text's
    def to_attachable_partial_path
      "users/attachable"
    end

    def to_editor_content_attachment_partial_path
      to_attachable_partial_path
    end
  end

  def mentioned_by(mentioner, at:)
    mentions.find_or_create_by! source: at, mentioner: mentioner
  end

  def mentionable_handles
    [ initials, first_name, first_name_with_last_name_initial ].collect(&:downcase)
  end

  def content_type
    "application/vnd.actiontext.mention"
  end

  private
    def first_name_with_last_name_initial
      "#{first_name}#{last_name&.first}"
    end
end
