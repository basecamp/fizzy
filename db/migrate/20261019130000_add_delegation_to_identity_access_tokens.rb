# RFC 8693 delegation (hosted plan, phase C). An API token the hosted MCP
# server gets from the exchange records the grant it was delegated from, the
# subject the server presented. Ending that grant sweeps its delegated tokens,
# and each API request checks the grant is still there.
#
# A nullable column and its index, no foreign key: the add is INSTANT, the
# index INPLACE, LOCK=NONE.
class AddDelegationToIdentityAccessTokens < ActiveRecord::Migration[8.2]
  def change
    add_reference :identity_access_tokens, :delegated_from, type: :uuid, foreign_key: false
  end
end
