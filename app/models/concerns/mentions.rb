module Mentions
  extend ActiveSupport::Concern

  included do
    has_many :mentions, as: :source, dependent: :destroy
    has_many :mentionees, through: :mentions
    after_save_commit :create_mentions_later, if: :mentionable_content_changed?
  end

  def create_mentions(mentioner: Current.user)
    scan_mentionees.each do |mentionee|
      mentionee.mentioned_by mentioner, at: self
    end
  end

  def mentionable_content
    rich_text_associations.collect { send(it.name)&.to_plain_text }.compact.join(" ")
  end

  private
    def scan_mentionees
      scan_mentioned_handles.filter_map do |mention|
        mentionable_users.find { |user| user.mentionable_handles.include?(mention) }
      end
    end

    def scan_mentioned_handles
      mentionable_content.scan(/(?<!\w)@(\w+)/).flatten.uniq(&:downcase)
    end

    def mentionable_users
      collection.users
    end

    def rich_text_associations
      self.class.reflect_on_all_associations(:has_one).filter { it.klass == ActionText::RichText }
    end

    def mentionable_content_changed?
      rich_text_associations.any? { send(it.name).body_previously_changed? }
    end

    def create_mentions_later
      Mention::CreateJob.perform_later(self, mentioner: Current.user)
    end
end
