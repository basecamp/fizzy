namespace :saas do
  namespace :reviewer_sign_in do
    desc "Generate a reviewer sign-in code and the digest to configure (FIZZY_REVIEWER_SIGN_IN_CODE_DIGEST)"
    task generate: :environment do
      code = Identity::ReviewerSignIn.generate_code

      puts "Code (give to reviewers; keep in 1Password, not in config): #{code}"
      puts "FIZZY_REVIEWER_SIGN_IN_CODE_DIGEST=#{Identity::ReviewerSignIn.digest(code)}"
    end

    desc "End every session of the configured reviewer identity and list its accounts' members (run after rotating the code)"
    task sign_out: :environment do
      puts "Ended #{Identity::ReviewerSignIn.sign_out_everywhere} reviewer session(s)"
      puts "Check these members; deactivate anyone who isn't the reviewer or the account's own staff:"
      Identity::ReviewerSignIn.members_of_reviewer_accounts.each do |account, users|
        puts "  #{account.name.inspect} (#{account.id}): #{users.size} active"
        users.each do |user|
          puts "    #{user.role} #{user.name.inspect} #{user.identity&.email_address.inspect} joined #{user.created_at.utc.iso8601}"
        end
      end
    end
  end
end
