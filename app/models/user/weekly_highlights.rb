# This acts as a join table between users and period_highlights so that we can reuse the
# same highlights for different users.
class User::WeeklyHighlights < ApplicationRecord
  belongs_to :user
  belongs_to :period_highlights
end
