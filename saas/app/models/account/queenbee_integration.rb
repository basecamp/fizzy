module Account::QueenbeeIntegration
  extend ActiveSupport::Concern

  include Queenbee::Client

  class_methods do
    def find_by_queenbee_id(id)
      find_by(external_account_id: id)
    end
  end

  def queenbee_id
    external_account_id
  end

  def cancel!
    cancel(initiated_by: system_user)
  end

  def uncancel!
    reactivate
  end

  def deactivate!
    cancel!
  end

  def reactivate!
    reactivate
  end

  def canceled?
    cancelled?
  end

  def owner_name
    users.owner.first&.name
  end

  def owner_email
    users.owner.first&.identity&.email_address
  end

  def transferred_ownership!
    raise NotImplementedError, "Fizzy does not support Queenbee-initiated ownership transfers"
  end

  def plan
    "FreeV1"
  end

  def comped?
    false
  end

  def comped=(value)
  end
end
