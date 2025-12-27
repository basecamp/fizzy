#!/usr/bin/env ruby

require_relative "../config/environment"

domains = {
  "production" => "app.fizzy.do",
  "beta" => ENV.fetch("APP_FQDN", "beta1.fizzy-beta.com"),
  "staging" => "app.fizzy-staging.com"
}

def fix_attachments(rich_text)
  if rich_text.body
    rich_text.body.send(:attachment_nodes).each do |node|
      sgid = SignedGlobalID.parse(node["sgid"], for: ActionText::Attachable::LOCATOR_NAME)
      if sgid
        puts "Fixing attachment node: #{node.to_html}"
        model = sgid.model_class.find(sgid.model_id)
        node["sgid"] = model.attachable_sgid
      else
        puts "Skipping attachment node without valid sgid: #{node.to_html}"
      end
    end
    rich_text.save!
  end
end

ApplicationRecord.with_each_tenant do |tenant|
  account_id = Current.account.queenbee_id

  unless account_id
    puts "Skipping URL fixup for tenant: #{tenant}"
    next
  end

  puts "\n## Processing tenant: #{tenant}\n"

  domain = domains[Rails.env] || domains["production"]
  regex = %r{://\w+\.#{domain}/}

  pp [ Current.account.name, account_id, domain, regex ]
  puts

  Card.find_each do |card|
    puts "### Processing card #{card.id} in #{Rails.application.routes.url_helpers.board_card_path(card.board, card)}"
    fix_attachments(card.description)
    card.reload

    old_body = card.description.body.to_s
    if match = regex.match(old_body)
      puts "URL found in card #{card.id} in #{Rails.application.routes.url_helpers.board_card_path(card.board, card)}"
      new_body = old_body.gsub(regex, "://#{domain}/#{account_id}/")

      card.description.update(body: new_body) || raise("Failed to update card description for card #{card.id}")
    end
  end

  Comment.find_each do |comment|
    puts "### Processing comment #{comment.id} in #{Rails.application.routes.url_helpers.board_card_path(comment.card.board, comment.card)}"
    fix_attachments(comment.body)
    comment.reload

    old_body = comment.body.body.to_s
    if match = regex.match(old_body)
      puts "URL found in comment #{comment.id} in #{Rails.application.routes.url_helpers.board_card_path(comment.card.board, comment.card)}"
      new_body = old_body.gsub(regex, "://#{domain}/#{account_id}/")

      comment.body.update(body: new_body) || raise("Failed to update comment body for comment #{comment.id}")
    end
  end
end
