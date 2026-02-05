class ActionPack::WebAuthn::PublicKeyCredential
  attr_reader :id, :public_key, :sign_count, :owner

  def initialize(id:, public_key:, sign_count:, owner: nil)
    @id = id
    @public_key = public_key
    @sign_count = sign_count
    @owner = owner
  end
end
