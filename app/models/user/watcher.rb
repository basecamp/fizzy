# rbs_inline: enabled

module User::Watcher
  extend ActiveSupport::Concern

  # @type self: singleton(User) & singleton(User::Watcher)
  included do
    has_many :watches, dependent: :destroy
  end
end
