class Identity < UntenantedRecord
  # This is used to instantiate an Identity-like object from the `identity_token` without hitting
  # the untenanted database. It is intended to be used with caching/etagging methods.
  Mock = Struct.new(:id, :updated_at) do
    def identity
      Identity.find_signed(id)
    end
  end

  has_many :memberships, dependent: :destroy
end
