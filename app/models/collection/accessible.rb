module Bucket::Accessible
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :delete_all do
      def revise(granted: [], revoked: [])
        transaction do
          grant_to granted
          revoke_from revoked
        end
      end

      def grant_to(users)
        Access.insert_all Array(users).collect { |user| { bucket_id: proxy_association.owner.id, user_id: user.id } }
      end

      def revoke_from(users)
        destroy_by user: users unless proxy_association.owner.all_access?
      end
    end

    has_many :users, through: :accesses
    has_many :access_only_users, -> { merge(Access.access_only) }, through: :accesses, source: :user

    scope :all_access, -> { where(all_access: true) }

    after_create -> { accesses.grant_to creator }
    after_save_commit :grant_access_to_everyone
  end

  def access_for(user)
    accesses.find_by(user: user)
  end

  private
    def grant_access_to_everyone
      accesses.grant_to(account.users) if all_access_previously_changed?(to: true)
    end
end
