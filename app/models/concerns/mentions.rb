module Mentions
  extend ActiveSupport::Concern

  included do
    has_many :mentions, as: :source, dependent: :destroy
    has_many :mentionees, through: :mentions
    after_save_commit :create_mentions_later, if: :should_create_mentions?
  end

  def create_mentions(mentioner: Current.user)
    scan_mentionees.each do |mentionee|
      mentionee.mentioned_by mentioner, at: self
    end
  end

  def mentionable_content
    rich_text_associations.collect { send(it.name)&.to_plain_text }.compact.join(" ")
  end

  def scan_mentionees
    mentionees_from_attachments & mentionable_users
  end

  private
    def mentionees_from_attachments
      rich_text_associations.flat_map { send(it.name)&.body&.attachments&.collect { it.attachable } }.compact
    end

    def mentionable_users
      board.users
    end

    def rich_text_associations
      self.class.reflect_on_all_associations(:has_one).filter { it.klass == ActionText::RichText }
    end

    def should_create_mentions?
      mentionable? && (mentionable_content_changed? || should_check_mentions?)
    end

    def mentionable_content_changed?
      rich_text_associations.any? { send(it.name)&.body_previously_changed? }
    end

    def create_mentions_later
      Mention::CreateJob.perform_later(self, mentioner: Current.user)
    end

    # Template method
    def mentionable?
      true
    end

    def should_check_mentions?
      false
    end
end
