module User::Watcher
  extend ActiveSupport::Concern
  included do
    has_many :watches, dependent: :destroy
  end
end
