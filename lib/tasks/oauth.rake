namespace :oauth do
  # The registry (Oauth::FirstPartyClients): the personal access client, and
  # each hosted MCP server whose resource FIZZY_OAUTH_MCP_RESOURCES names here.
  # A secret is never minted or rotated; a client without one is named, for
  # oauth:mint_client_secret.
  desc "Create or converge Fizzy's first-party OAuth clients, all in one transaction"
  task provision_first_party_clients: :environment do
    Oauth::FirstPartyClients.provision!.each do |client|
      puts "#{client.client_id}: #{client.previously_new_record? ? "created" : "converged"}"

      if Oauth::FirstPartyClients.awaiting_secret?(client)
        puts "  #{client.client_id} has no secret yet. Give it one with: bin/rails \"oauth:mint_client_secret[#{client.client_id}]\""
      end
    end
  rescue ArgumentError => error
    abort error.message
  end

  # For an MCP server the registry doesn't host, such as a self-hosted
  # install's. Its client converges over the registry's baseline, as a
  # hosted one does.
  desc "Create or converge an MCP server's OAuth client outside the registry (RESOURCE=https://mcp.example.com/mcp, or the one FIZZY_OAUTH_MCP_RESOURCES names; CLIENT_ID=… for each resource past the first)"
  task provision_mcp_client: :environment do
    resource = ENV["RESOURCE"].presence || (Oauth.mcp_resources.one? ? Oauth.mcp_resources.first : nil)

    if resource.nil?
      abort "Name the MCP server's resource with RESOURCE=…, or configure exactly one in FIZZY_OAUTH_MCP_RESOURCES"
    elsif !Oauth.mcp_resource?(resource)
      abort "#{resource} isn't in FIZZY_OAUTH_MCP_RESOURCES, so its client couldn't exchange tokens"
    else
      client = Oauth::FirstPartyClients.provision_mcp_server!(resource, client_id: ENV["CLIENT_ID"].presence)
      puts "#{client.client_id} fronts #{client.protected_resource}. Give it a secret with: bin/rails \"oauth:mint_client_secret[#{client.client_id}]\""
    end
  rescue ArgumentError => error
    abort error.message
  end

  desc "Mint a new secret for an operator-provisioned confidential client, printed once; the old one stops working"
  task :mint_client_secret, [ :client_id ] => :environment do |_task, args|
    client = Oauth::Client.find_by!(client_id: args.fetch(:client_id))
    secret = client.rotate_secret!

    puts "Secret for #{client.client_id} (shown once, store it now):"
    puts secret
  end
end
