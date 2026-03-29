class AgentBootstrapClaimsController < ApplicationController
  disallow_account_scope
  allow_unauthenticated_access
  wrap_parameters :agent_bootstrap, include: %i[ email_address name profile_name ]

  def create
    bootstrap = Board::AgentBootstrap.find_by!(token: params.expect(:token))
    claim = bootstrap.claim!(**claim_params.to_h.symbolize_keys)

    render json: {
      token: claim[:access_token].token,
      permission: claim[:access_token].permission,
      account: {
        id: bootstrap.account.id,
        name: bootstrap.account.name,
        slug: bootstrap.account.slug
      },
      board: {
        id: bootstrap.board.id,
        name: bootstrap.board.name,
        url: board_url(bootstrap.board, script_name: bootstrap.account.slug)
      },
      user: {
        id: claim[:user].id,
        name: claim[:user].name,
        email_address: claim[:identity].email_address
      },
      profile: {
        base_url: root_url(script_name: nil).delete_suffix("/"),
        account_slug: bootstrap.account.slug,
        default_board_id: bootstrap.board.id
      }
    }, status: :created
  rescue ActiveRecord::RecordNotFound
    head :gone
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end

  private
    def claim_params
      params.expect(agent_bootstrap: %i[ email_address name profile_name ])
        .with_defaults(profile_name: nil)
    end
end
