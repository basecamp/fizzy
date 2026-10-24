namespace :oauth do
  desc "Create or converge the hosted MCP server's OAuth client (RESOURCE=https://mcp.example.com/mcp, or the one FIZZY_OAUTH_MCP_RESOURCES names; CLIENT_ID=… for each resource past the first)"
  task provision_mcp_client: :environment do
    resource = ENV["RESOURCE"].presence || (Oauth.mcp_resources.one? ? Oauth.mcp_resources.first : nil)

    if resource.nil?
      abort "Name the MCP server's resource with RESOURCE=…, or configure exactly one in FIZZY_OAUTH_MCP_RESOURCES"
    elsif !Oauth.mcp_resource?(resource)
      abort "#{resource} isn't in FIZZY_OAUTH_MCP_RESOURCES, so its client couldn't exchange tokens"
    else
      client = Oauth::Client.provision_mcp_client! \
        protected_resource: resource, client_id: ENV["CLIENT_ID"].presence || Oauth::Client::MCP_CLIENT_ID
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
