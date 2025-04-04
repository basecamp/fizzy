class Pop < ApplicationRecord
  belongs_to :bubble, touch: true
  belongs_to :user, optional: true

  def reason
    super || Pop::Reason::FALLBACK_LABEL
  end
end
