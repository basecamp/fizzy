namespace :saas do
  namespace :reviewer_sign_in do
    desc "Generate a reviewer sign-in code; with EMAIL=, print FIZZY_REVIEWER_SIGN_IN_CODES with that reviewer added (or its code replaced)"
    task generate: :environment do
      code = Identity::ReviewerSignIn.generate_code
      digest = Identity::ReviewerSignIn.digest(code)

      puts "Code (give to reviewers; keep in 1Password, not in config): #{code}"

      if ENV["EMAIL"].present?
        puts "FIZZY_REVIEWER_SIGN_IN_CODES=#{Identity::ReviewerSignIn.code_digests_with(ENV["EMAIL"], digest)}"
      else
        puts "FIZZY_REVIEWER_SIGN_IN_CODE_DIGEST=#{digest}"
      end
    end

    desc "End the sessions of every reviewer identity, or of EMAIL= alone, and list their accounts' members and connected apps (run after rotating a code). Leaves connected apps connected."
    task sign_out: :environment do
      puts "Ended #{Identity::ReviewerSignIn.sign_out_everywhere(ENV["EMAIL"])} reviewer session(s)"
      puts "Check these members; deactivate anyone who isn't a reviewer or the account's own staff:"
      Identity::ReviewerSignIn.members_of_reviewer_accounts(ENV["EMAIL"]).each do |account, users|
        puts "  #{account.name.inspect} (#{account.id}): #{users.size} active"
        users.each do |user|
          puts "    #{user.role} #{user.name.inspect} #{user.identity&.email_address.inspect} joined #{user.created_at.utc.iso8601}"
        end
      end
      puts "Check these connected apps; disconnect any that isn't the partner's with saas:reviewer_sign_in:revoke_grants EMAIL=:"
      Identity::ReviewerSignIn.oauth_grants_of_reviewers(ENV["EMAIL"]).each do |identity, grants|
        puts "  #{identity.email_address.inspect}: #{grants.size} connected"
        grants.each do |grant|
          puts "    #{grant.oauth_client&.name.inspect} (#{grant.oauth_client&.client_id}) connected #{grant.created_at.utc.iso8601}"
        end
      end
    end

    desc "Disconnect every app connected as the reviewer EMAIL= (explicit cleanup; sign_out never does this)"
    task revoke_grants: :environment do
      if ENV["EMAIL"].present?
        puts "Disconnected #{Identity::ReviewerSignIn.revoke_oauth_grants(ENV["EMAIL"])} app(s) from #{ENV["EMAIL"]}"
      else
        abort "Name the reviewer: EMAIL=reviewer@example.com"
      end
    end
  end
end
