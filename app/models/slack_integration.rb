class SlackIntegration < ApplicationRecord
  include Colored

  belongs_to :account, default: -> { board.account }
  belongs_to :board
  has_many :slack_items, dependent: :destroy
  has_many :deliveries, class_name: "SlackIntegration::Delivery", dependent: :destroy

  validates :channel_id, presence: true,
    uniqueness: { scope: :board_id }
  validates :channel_name, presence: true
  validates :webhook_secret, presence: true

  # Serialize emoji_action_mappings as JSON
  # Format: { "white_check_mark" => { "action" => "move_to_column", "column_id" => "xyz" }, ... }
  attribute :emoji_action_mappings, :json, default: {}

  # Ensure emoji_action_mappings is always a hash for safe reading
  def emoji_action_mappings
    value = read_attribute(:emoji_action_mappings)
    return {} if value.nil?
    return value if value.is_a?(Hash)

    # If it's a string, try to parse it (shouldn't happen with :json attribute, but defensive)
    if value.is_a?(String)
      begin
        parsed = JSON.parse(value)
        return parsed.is_a?(Hash) ? parsed : {}
      rescue JSON::ParserError
        Rails.logger.error "Failed to parse emoji_action_mappings: #{value}"
        return {}
      end
    end

    {}
  end

  scope :active, -> { where(active: true) }
  scope :for_channel, ->(channel_id) { where(channel_id: channel_id) }

  def activate
    update_column(:active, true)
  end

  def deactivate
    update_column(:active, false)
  end

  def webhook_url
    Rails.application.routes.url_helpers.slack_webhooks_url(
      id: id,
      script_name: account.slug,
      host: Rails.application.config.action_mailer.default_url_options[:host]
    )
  end

  def should_sync_event?(event_type)
    Rails.logger.info "🔍 should_sync_event? called for: #{event_type}"
    Rails.logger.info "Integration active?: #{active?}"
    
    unless active?
      Rails.logger.info "⏭️  Integration is not active, returning false"
      return false
    end

    # Check account-level settings (default to true if not configured)
    account_allows = account.slack_setting&.allows_event?(event_type) != false
    Rails.logger.info "Account allows event?: #{account_allows}"
    Rails.logger.info "Account slack_setting: #{account.slack_setting&.inspect}"
    
    unless account_allows
      Rails.logger.info "⏭️  Account-level setting disallows event, returning false"
      return false
    end

    result = case event_type
    when "message" 
      Rails.logger.info "sync_messages setting: #{sync_messages}"
      sync_messages
    when "thread_reply" 
      Rails.logger.info "sync_thread_replies setting: #{sync_thread_replies}"
      sync_thread_replies
    when "reaction_added" 
      Rails.logger.info "sync_reactions setting: #{sync_reactions}"
      sync_reactions
    else 
      Rails.logger.info "Unknown event type, returning false"
      false
    end
    
    Rails.logger.info "should_sync_event? result: #{result}"
    result
  end

  def sync_message(payload)
    message_data = payload["event"]

    Rails.logger.info "📨 sync_message called"
    Rails.logger.info "Message text: #{message_data['text']&.truncate(200)}"
    Rails.logger.info "Bot ID: #{message_data['bot_id']}"
    Rails.logger.info "Subtype: #{message_data['subtype']}"
    Rails.logger.info "Thread TS: #{message_data['thread_ts']}"
    Rails.logger.info "Message TS: #{message_data['ts']}"
    Rails.logger.info "Current.account: #{Current.account&.id}"
    Rails.logger.info "Integration bot_user_id: #{bot_user_id.inspect}"
    Rails.logger.info "Integration bot_oauth_token present: #{bot_oauth_token.present?}"

    # Skip bot messages and message subtypes we don't want to sync
    if message_data["bot_id"].present?
      Rails.logger.info "⏭️  Skipping bot message (bot_id: #{message_data['bot_id']})"
      return
    end

    if message_data["subtype"].present? && !["thread_broadcast"].include?(message_data["subtype"])
      Rails.logger.info "⏭️  Skipping message with subtype: #{message_data['subtype']}"
      return
    end

    # Check if this is a thread reply
    if message_data["thread_ts"].present? && message_data["thread_ts"] != message_data["ts"]
      Rails.logger.info "📝 This is a thread reply"
      if should_sync_event?("thread_reply")
        sync_thread_reply(message_data)
      else
        Rails.logger.info "⏭️  Thread replies are disabled for this integration"
      end
    else
      Rails.logger.info "💬 This is a new message (not a thread reply)"
      Rails.logger.info "=" * 80
      Rails.logger.info "DECISION POINT: Should we create a card?"
      # Only create cards if bot is mentioned (or if bot_user_id not configured - backward compatibility)
      mentions_bot = message_mentions_bot?(message_data)
      Rails.logger.info "Bot user ID blank: #{bot_user_id.blank?}"
      Rails.logger.info "Message mentions bot: #{mentions_bot}"
      Rails.logger.info "Will create card? #{bot_user_id.blank? || mentions_bot}"
      Rails.logger.info "=" * 80
      
      if bot_user_id.blank? || mentions_bot
        Rails.logger.info "✅ PROCEEDING TO CREATE CARD FROM MESSAGE"
        begin
          card = create_card_from_message(message_data)
          Rails.logger.info "✅ Card created: ##{card.number} - #{card.title}"
          if card && bot_oauth_token.present?
            Rails.logger.info "📤 Sending thread reply to Slack"
            send_thread_reply(message_data, card)
          else
            Rails.logger.warn "⚠️  Not sending thread reply - card: #{card.present?}, bot_oauth_token: #{bot_oauth_token.present?}"
          end
        rescue => e
          Rails.logger.error "❌ Error creating card from message: #{e.message}"
          Rails.logger.error "Error class: #{e.class.name}"
          Rails.logger.error "Backtrace:\n#{e.backtrace.first(15).join("\n")}"
          raise
        end
      else
        Rails.logger.info "⏭️  Message does not mention bot, skipping card creation"
        Rails.logger.info "Message text: #{message_data['text']}"
        Rails.logger.info "Looking for: <@#{bot_user_id}>"
      end
    end
    
    Rails.logger.info "=" * 80
    Rails.logger.info "sync_message COMPLETED"
    Rails.logger.info "=" * 80
  end

  def message_mentions_bot?(message_data)
    text = message_data["text"].to_s

    # Check if bot user ID is in the text (format: <@U123456789>)
    mention_pattern = "<@#{bot_user_id}>"
    mentions = text.include?(mention_pattern)
    Rails.logger.info "Checking if message mentions bot: text includes '#{mention_pattern}'? #{mentions}"
    mentions
  end

  def send_thread_reply(message_data, card)
    require 'net/http'
    require 'json'

    unless bot_oauth_token.present?
      Rails.logger.warn "⚠️  Cannot send thread reply: bot_oauth_token is not configured"
      return
    end

    Rails.logger.info "📤 Preparing thread reply for message #{message_data['ts']}"
    Rails.logger.info "Card: ##{card.number} - #{card.title}"
    Rails.logger.info "Current.account: #{Current.account&.id}"

    # Build emoji instructions
    emoji_instructions = build_emoji_instructions

    begin
      card_url_string = card_url(card)
      Rails.logger.info "Card URL: #{card_url_string}"
    rescue => e
      Rails.logger.error "❌ Error building card URL: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      card_url_string = "Card ##{card.number}"
    end

    message_text = "✅ *Card created in Fizzy!*\n\n" \
                   "View card: <#{card_url_string}|Card ##{card.number}: #{card.title}>\n\n" \
                   "#{emoji_instructions}"

    uri = URI('https://slack.com/api/chat.postMessage')
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{bot_oauth_token}"
    request['Content-Type'] = 'application/json'
    request.body = {
      channel: message_data["channel"],
      thread_ts: message_data["ts"],  # Reply in thread
      text: message_text
    }.to_json

    Rails.logger.info "📤 Sending thread reply to Slack API"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)
    if result["ok"]
      Rails.logger.info "✅ Thread reply sent successfully"
    else
      Rails.logger.error "❌ Failed to send thread reply: #{result['error']}"
      Rails.logger.error "Full response: #{result.inspect}"
    end
  rescue => error
    Rails.logger.error "❌ Error sending thread reply: #{error.message}"
    Rails.logger.error "Error class: #{error.class.name}"
    Rails.logger.error "Backtrace:\n#{error.backtrace.first(10).join("\n")}"
    # Don't re-raise - we don't want Slack API failures to break webhook processing
  end

  def send_emoji_action_feedback(message_ts, card, emoji, result)
    require 'net/http'
    require 'json'

    unless bot_oauth_token.present?
      Rails.logger.warn "⚠️  Cannot send emoji action feedback: bot_oauth_token is not configured"
      return
    end

    # Build feedback message based on action result
    message_text = case result[:action]
    when "moved"
      "✅ Card moved to *#{result[:column_name]}*\n\nView card: <#{card_url(card)}|Card ##{card.number}: #{card.title}>"
    when "closed"
      "✅ Card closed\n\nView card: <#{card_url(card)}|Card ##{card.number}: #{card.title}>"
    when "postponed"
      "✅ Card postponed (Not Now)\n\nView card: <#{card_url(card)}|Card ##{card.number}: #{card.title}>"
    when "reopened"
      "✅ Card reopened\n\nView card: <#{card_url(card)}|Card ##{card.number}: #{card.title}>"
    else
      return # Unknown action, don't send feedback
    end

    uri = URI('https://slack.com/api/chat.postMessage')
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{bot_oauth_token}"
    request['Content-Type'] = 'application/json'
    request.body = {
      channel: channel_id,
      thread_ts: message_ts,  # Reply in thread
      text: message_text
    }.to_json

    Rails.logger.info "📤 Sending emoji action feedback for :#{emoji}: action"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)
    if result["ok"]
      Rails.logger.info "✅ Emoji action feedback sent successfully"
    else
      Rails.logger.error "❌ Failed to send emoji action feedback: #{result['error']}"
    end
  rescue => error
    Rails.logger.error "❌ Error sending emoji action feedback: #{error.message}"
    # Don't re-raise - we don't want feedback failures to break webhook processing
  end

  def build_emoji_instructions
    return "" if emoji_action_mappings.blank?

    instructions = "*React with these emojis to take action:*\n"

    emoji_action_mappings.each do |emoji, config|
      action_text = case config["action"]
      when "move_to_column"
        column = board.columns.find_by(id: config["column_id"])
        column ? "Move to #{column.name}" : "Move to column (column deleted)"
      when "close"
        "Close card"
      when "postpone"
        "Postpone (Not Now)"
      when "reopen"
        "Reopen card"
      else
        "Unknown action"
      end

      instructions += "• :#{emoji}: → #{action_text}\n"
    end

    instructions
  end

  def card_url(card)
    Rails.application.routes.url_helpers.board_card_url(
      card.board,
      card,
      script_name: account.slug,
      host: Rails.application.config.action_mailer.default_url_options[:host],
      protocol: 'http'
    )
  end

  def sync_thread_reply(message_data)
    slack_item = slack_items.find_by(slack_message_ts: message_data["thread_ts"])
    return unless slack_item

    slack_item.card.add_slack_comment(message_data)
  end

  def sync_reaction(payload)
    event_data = payload["event"]
    message_ts = event_data.dig("item", "ts")

    Rails.logger.info "Looking for SlackItem with message_ts: #{message_ts}"

    slack_item = slack_items.find_by(slack_message_ts: message_ts)
    unless slack_item
      Rails.logger.warn "⚠️  No SlackItem found for message timestamp: #{message_ts}"
      Rails.logger.warn "This might be a reaction on a message that wasn't synced to Fizzy"
      return
    end

    emoji = event_data["reaction"]
    card = slack_item.card

    Rails.logger.info "Processing reaction for card ##{card.number} (#{card.title&.truncate(50)})"
    Rails.logger.info "Emoji: #{emoji}"

    # Check if this emoji has an action mapping
    if emoji_action_mappings.present? && emoji_action_mappings[emoji].present?
      Rails.logger.info "Action mapping found for emoji '#{emoji}': #{emoji_action_mappings[emoji].inspect}"
      action_result = execute_emoji_action(card, emoji, emoji_action_mappings[emoji])

      # Send feedback to Slack if action was successful and we have a bot token
      if action_result && bot_oauth_token.present?
        send_emoji_action_feedback(message_ts, card, emoji, action_result)
      end
    else
      Rails.logger.info "No action mapping found for emoji '#{emoji}', adding comment"
      # Default behavior: just add a comment about the reaction
      card.add_slack_reaction(event_data)
      Rails.logger.info "✅ Added reaction comment to card"
    end
  end

  def execute_emoji_action(card, emoji, action_config)
    Rails.logger.info "🎬 execute_emoji_action called"
    Rails.logger.info "Card: ##{card.number} (#{card.id})"
    Rails.logger.info "Emoji: #{emoji}"
    Rails.logger.info "Action config: #{action_config.inspect}"
    Rails.logger.info "Current.account: #{Current.account&.id}"
    Rails.logger.info "Card.account: #{card.account&.id}"
    Rails.logger.info "Integration.account: #{account&.id}"

    unless action_config.is_a?(Hash)
      Rails.logger.error "❌ Invalid action config (not a Hash): #{action_config.inspect}"
      return
    end

    action = action_config["action"]

    unless action.present?
      Rails.logger.error "❌ Action missing in config: #{action_config.inspect}"
      return
    end

    Rails.logger.info "🎬 Executing emoji action: #{action}"

    begin
      # Use account owner instead of system user
      user = account.users.owner.first || account.system_user
      Rails.logger.info "User for action: #{user.id} (#{user.name})"
      case action
      when "move_to_column"
        column_id = action_config["column_id"]
        unless column_id.present?
          Rails.logger.error "❌ Column ID missing in action config"
          return
        end

        column = board.columns.find_by(id: column_id)
        unless column
          Rails.logger.error "❌ Column not found: #{column_id}"
          Rails.logger.error "Available columns: #{board.columns.pluck(:id, :name).inspect}"
          return
        end

        if card.column_id == column_id && !card.postponed? && !card.closed?
          Rails.logger.info "⏭️  Card is already in column '#{column.name}' and active, skipping"
          return nil
        end

        # Reopen card if it's closed or postponed
        if card.closed?
          Rails.logger.info "Card is closed, reopening before moving"
          card.reopen(user: user)
        elsif card.postponed?
          Rails.logger.info "Card is postponed, resuming before moving"
          card.resume
        end

        Rails.logger.info "Moving card ##{card.number} to column: #{column.name} (#{column_id})"
        card.update!(column_id: column_id)
        Rails.logger.info "Card updated, column_id is now: #{card.reload.column_id}"
        card.track_event :moved, creator: user, particulars: {
          column_name: column.name,
          via: "slack_reaction",
          emoji: emoji
        }
        Rails.logger.info "✅ Card moved to '#{column.name}' and event tracked"

        return { action: "moved", column_name: column.name }

      when "close"
        if card.closed?
          Rails.logger.info "⏭️  Card is already closed, skipping"
          return nil
        end

        # Resume (unpostpone) before closing if needed
        if card.postponed?
          Rails.logger.info "Card is postponed, resuming before closing"
          card.resume
        end

        Rails.logger.info "Closing card ##{card.number}"
        card.close(user: user)
        Rails.logger.info "Card closed status: #{card.reload.closed?}"
        Rails.logger.info "✅ Card closed"

        return { action: "closed" }

      when "postpone"
        if card.postponed?
          Rails.logger.info "⏭️  Card is already postponed, skipping"
          return nil
        end

        # Reopen before postponing if card is closed
        if card.closed?
          Rails.logger.info "Card is closed, reopening before postponing"
          card.reopen(user: user)
        end

        Rails.logger.info "Postponing card ##{card.number}"
        card.postpone(user: user)
        Rails.logger.info "Card postponed status: #{card.reload.postponed?}"
        Rails.logger.info "✅ Card postponed"

        return { action: "postponed" }

      when "reopen"
        if card.postponed?
          Rails.logger.info "Card is postponed, resuming"
          card.resume
          Rails.logger.info "✅ Card resumed (active)"
          return { action: "reopened" }
        elsif card.closed?
          Rails.logger.info "Reopening card ##{card.number}"
          card.reopen(user: user)
          Rails.logger.info "Card closed status after reopen: #{card.reload.closed?}"
          Rails.logger.info "✅ Card reopened"
          return { action: "reopened" }
        else
          Rails.logger.info "⏭️  Card is already active, skipping"
          return nil
        end

      else
        Rails.logger.warn "⚠️  Unknown action type: #{action}"
        return nil
      end

    rescue => error
      Rails.logger.error "❌ Error executing emoji action: #{error.message}"
      Rails.logger.error "Error class: #{error.class.name}"
      Rails.logger.error "Action: #{action}"
      Rails.logger.error "Action config: #{action_config.inspect}"
      Rails.logger.error "Card: ##{card.number}"
      Rails.logger.error "Emoji: #{emoji}"
      Rails.logger.error "Current.account: #{Current.account&.id}"
      Rails.logger.error "Card.account: #{card.account&.id}"
      Rails.logger.error "Integration.account: #{account&.id}"
      Rails.logger.error "Backtrace:\n#{error.backtrace.first(15).join("\n")}"
      raise
    end
  end

  private
    def create_card_from_message(message_data)
      Rails.logger.info "🎴 create_card_from_message called"
      Rails.logger.info "Current.account: #{Current.account&.id}"
      Rails.logger.info "Integration.account: #{account&.id}"
      Rails.logger.info "Board: #{board.id} - #{board.name}"

      # Use account owner instead of system user
      creator = account.users.owner.first || account.system_user
      Rails.logger.info "Creator: #{creator.id} (#{creator.name})"

      title = extract_title_from_message(message_data["text"])
      Rails.logger.info "Card title: #{title}"

      description = build_message_description(message_data)
      Rails.logger.info "Card description length: #{description.length}"

      Rails.logger.info "Creating card..."
      card = board.cards.create!(
        creator: creator,
        status: "published",
        title: title,
        description: description
      )
      Rails.logger.info "✅ Card created: ##{card.number} (#{card.id})"

      Rails.logger.info "Creating SlackItem..."
      slack_items.create!(
        card: card,
        slack_message_ts: message_data["ts"],
        slack_user_id: message_data["user"],
        channel_id: message_data["channel"],
        last_synced_at: Time.current
      )
      Rails.logger.info "✅ SlackItem created"

      card
    rescue => e
      Rails.logger.error "❌ Error in create_card_from_message: #{e.message}"
      Rails.logger.error "Error class: #{e.class.name}"
      Rails.logger.error "Current.account: #{Current.account&.id}"
      Rails.logger.error "Integration.account: #{account&.id}"
      Rails.logger.error "Board: #{board&.id}"
      Rails.logger.error "Backtrace:\n#{e.backtrace.first(15).join("\n")}"
      raise
    end

    def extract_title_from_message(text)
      # Strip bot mention from text
      cleaned_text = strip_bot_mention(text)

      # Take first line or first 100 chars, whichever is shorter
      first_line = cleaned_text.to_s.lines.first&.strip || "Slack message"
      first_line.truncate(100)
    end

    def build_message_description(message_data)
      # Strip bot mention from text
      cleaned_text = strip_bot_mention(message_data["text"])

      permalink = build_slack_permalink(message_data["ts"])
      <<~HTML
        <p><strong>Slack Message</strong></p>
        #{permalink ? "<p><a href=\"#{permalink}\">View in Slack</a></p>" : ""}
        <p>#{format_slack_text(cleaned_text)}</p>
      HTML
    end

    def build_slack_permalink(message_ts)
      # Slack permalink format: https://workspace.slack.com/archives/CHANNEL_ID/pMESSAGE_TS
      # Note: This is a simplified version. In production, you'd need the workspace domain
      return nil unless workspace_domain.present?

      message_id = "p#{message_ts.gsub('.', '')}"
      "https://#{workspace_domain}.slack.com/archives/#{channel_id}/#{message_id}"
    end

    def strip_bot_mention(text)
      return text unless bot_user_id.present?

      # Remove bot mention (format: <@U123456789>)
      text.to_s.gsub("<@#{bot_user_id}>", '').strip
    end

    def format_slack_text(text)
      # Basic Slack formatting conversion (could be enhanced)
      text.to_s
        .gsub(/\*([^*]+)\*/, '<strong>\1</strong>')  # Bold
        .gsub(/_([^_]+)_/, '<em>\1</em>')             # Italic
        .gsub(/~([^~]+)~/, '<del>\1</del>')           # Strikethrough
        .gsub(/\n/, '<br>')                           # Line breaks
    end
end
