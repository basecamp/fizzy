class Account::Cancellation < ApplicationRecord
  belongs_to :account
  belongs_to :initiated_by, class_name: "User"
end
