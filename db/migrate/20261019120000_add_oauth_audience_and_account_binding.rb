# RFC 8707 audience and account binding for OAuth grants (hosted plan, phase B).
#
# A grant asked for on behalf of a protected resource other than Fizzy's own
# API (the hosted MCP server) records that resource as its audience, stamped
# once at consent and kept through every rotation. Such a grant is bound to the
# one account the person picked at consent. A grant with neither stays
# identity-wide, as every grant and personal access token is today.
#
# A confidential client that fronts a protected resource (the MCP server's own
# client, for the delegation exchange) names it in protected_resource.
#
# Nullable columns only, and no foreign keys: every add is INSTANT, and the
# index is INPLACE, LOCK=NONE.
#
# Each step is skipped when it's already done, so a run that stopped partway
# (MySQL commits each DDL statement on its own) can simply be run again.
class AddOauthAudienceAndAccountBinding < ActiveRecord::Migration[8.2]
  def change
    add_column :identity_access_tokens, :audience, :string, limit: 255, if_not_exists: true
    add_reference :identity_access_tokens, :account, type: :uuid, foreign_key: false, if_not_exists: true

    add_column :oauth_clients, :protected_resource, :string, limit: 255, if_not_exists: true
  end
end
