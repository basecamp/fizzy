require "json"
require "thor"

require_relative "client"
require_relative "config_store"
require_relative "version"

module Fizzy
  module CLIHelpers
    private
      def config_store
        @config_store ||= ConfigStore.new
      end

      def selected_profile_name
        options[:profile] || ENV["FIZZY_PROFILE"] || config_store.current_profile_name
      end

      def profile_settings(require_token: true, require_account: true)
        profile = config_store.profile(selected_profile_name) || {}

        base_url = ENV["FIZZY_BASE_URL"] || profile["base_url"]
        token = ENV["FIZZY_TOKEN"] || profile["token"]
        account_slug = ENV["FIZZY_ACCOUNT"] || profile["account_slug"]
        default_board_id = profile["default_board_id"]

        raise Error, "No active profile. Run `fizzy auth bootstrap ...` first." if base_url.to_s.empty?
        raise Error, "No API token configured for the active profile." if require_token && token.to_s.empty?
        raise Error, "No account configured for the active profile." if require_account && account_slug.to_s.empty?

        {
          "base_url" => base_url,
          "token" => token,
          "account_slug" => account_slug,
          "default_board_id" => default_board_id
        }
      end

      def client
        settings = profile_settings(require_account: false)
        @client ||= Client.new(base_url: settings.fetch("base_url"), token: settings["token"])
      end

      def account_scoped_path(path)
        settings = profile_settings
        slug = settings.fetch("account_slug")
        path = path.delete_prefix("/")
        "/#{slug}/#{path}"
      end

      def request(method, path, params: nil, account_scope: true)
        target = account_scope ? account_scoped_path(path) : path
        client.request(method, target, params:)
      end

      def request_with_full_url(method, url, params: nil)
        client.request(method, url, params:)
      end

      def default_board_id
        profile_settings["default_board_id"] || raise(Error, "No default board configured; pass --board.")
      end

      def compact_hash(hash)
        hash.each_with_object({}) do |(key, value), compacted|
          compacted[key] = value unless value.nil?
        end
      end

      def parse_json(value)
        JSON.parse(value)
      rescue JSON::ParserError => error
        raise Error, "Invalid JSON payload: #{error.message}"
      end

      def render_output(payload, empty_message: "OK")
        if options[:json]
          puts(JSON.pretty_generate(payload.nil? ? { "ok" => true } : payload))
          return
        end

        case payload
        when nil
          puts empty_message
        when Array
          payload.each { |item| puts human_line(item) }
        when Hash
          puts human_hash(payload)
        else
          puts payload
        end
      end

      def human_line(item)
        return item unless item.is_a?(Hash)

        compact = [ item["id"], item["number"], item["name"], item["title"], item["url"] ].compact
        compact.empty? ? item.inspect : compact.join("  ")
      end

      def human_hash(payload)
        summary_keys = %w[id number name title status token permission url]
        summary = payload.slice(*summary_keys).compact
        return summary.map { |key, value| "#{key}: #{value}" }.join("\n") if summary.any?

        JSON.pretty_generate(payload)
      end
  end

  class AuthCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "bootstrap URL", "Claim a one-time bootstrap URL and save a local profile"
    option :email, type: :string, required: true, desc: "Identity email address for this agent"
    option :name, type: :string, required: true, desc: "Display name for this agent"
    option :profile_name, type: :string, desc: "Name embedded in the access token description"
    def bootstrap(url)
      bootstrap_client = Client.new(base_url: ENV["FIZZY_BASE_URL"] || url)
      response = bootstrap_client.request(:post, url, params: {
        email_address: options[:email],
        name: options[:name],
        profile_name: options[:profile_name]
      })

      profile_name = options[:profile] || options[:profile_name] || "#{response.dig("account", "slug")}-#{options[:email].split("@").first}"

      config_store.save_profile(profile_name, {
        "base_url" => response.dig("profile", "base_url"),
        "account_slug" => response.dig("profile", "account_slug"),
        "default_board_id" => response.dig("profile", "default_board_id"),
        "token" => response.fetch("token"),
        "user_name" => response.dig("user", "name"),
        "user_email" => response.dig("user", "email_address")
      })

      render_output(response.merge("profile_name" => profile_name), empty_message: "Saved profile #{profile_name}")
    end

    desc "profiles", "List saved CLI profiles"
    def profiles
      payload = {
        "current_profile" => config_store.current_profile_name,
        "profiles" => config_store.profiles
      }
      render_output(payload)
    end

    desc "use NAME", "Select the active CLI profile"
    def use(name)
      config_store.set_current_profile(name)
      render_output({ "current_profile" => name }, empty_message: "Using profile #{name}")
    end
  end

  class AccountsCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list", "List the active identity's Fizzy accounts"
    def list
      response = request(:get, "/my/identity", account_scope: false)
      render_output(response.fetch("accounts"))
    end
  end

  class BoardsCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list", "List boards"
    def list
      render_output(request(:get, "boards"))
    end

    desc "get BOARD_ID", "Fetch a board"
    def get(board_id)
      render_output(request(:get, "boards/#{board_id}"))
    end

    desc "create NAME", "Create a board"
    option :all_access, type: :boolean, default: true
    option :auto_postpone_days, type: :numeric
    option :public_description, type: :string
    def create(name)
      render_output(request(:post, "boards", params: compact_hash(
        name:,
        all_access: options[:all_access],
        auto_postpone_period_in_days: options[:auto_postpone_days],
        public_description: options[:public_description]
      )))
    end

    desc "update BOARD_ID", "Update a board"
    option :name, type: :string
    option :all_access, type: :boolean
    option :auto_postpone_days, type: :numeric
    option :public_description, type: :string
    def update(board_id)
      render_output(request(:put, "boards/#{board_id}", params: compact_hash(
        name: options[:name],
        all_access: options[:all_access],
        auto_postpone_period_in_days: options[:auto_postpone_days],
        public_description: options[:public_description]
      )))
    end

    desc "delete BOARD_ID", "Delete a board"
    def delete(board_id)
      render_output(request(:delete, "boards/#{board_id}"))
    end

    desc "watch BOARD_ID", "Watch a board for new cards"
    def watch(board_id)
      render_output(request(:put, "boards/#{board_id}/involvement", params: { involvement: "watching" }))
    end

    desc "unwatch BOARD_ID", "Stop watching a board"
    def unwatch(board_id)
      render_output(request(:put, "boards/#{board_id}/involvement", params: { involvement: "access_only" }))
    end
  end

  class ColumnsCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list [BOARD_ID]", "List columns on a board"
    def list(board_id = nil)
      render_output(request(:get, "boards/#{board_id || default_board_id}/columns"))
    end

    desc "get BOARD_ID COLUMN_ID", "Fetch a column"
    def get(board_id, column_id)
      render_output(request(:get, "boards/#{board_id}/columns/#{column_id}"))
    end

    desc "create NAME", "Create a column"
    option :board, type: :string
    def create(name)
      render_output(request(:post, "boards/#{options[:board] || default_board_id}/columns", params: { name: }))
    end

    desc "update BOARD_ID COLUMN_ID", "Rename a column"
    option :name, type: :string, required: true
    def update(board_id, column_id)
      render_output(request(:put, "boards/#{board_id}/columns/#{column_id}", params: { name: options[:name] }))
    end

    desc "delete BOARD_ID COLUMN_ID", "Delete a column"
    def delete(board_id, column_id)
      render_output(request(:delete, "boards/#{board_id}/columns/#{column_id}"))
    end
  end

  class CardsCommand < Thor
    include CLIHelpers
    map "self-assign" => :self_assign

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list", "List cards visible to the current user"
    def list
      render_output(request(:get, "cards"))
    end

    desc "get CARD_NUMBER", "Fetch a card"
    def get(card_number)
      render_output(request(:get, "cards/#{card_number}"))
    end

    desc "create TITLE", "Create a card"
    option :board, type: :string
    option :description, type: :string
    def create(title)
      board_id = options[:board] || default_board_id
      render_output(request(:post, "boards/#{board_id}/cards", params: compact_hash(title:, description: options[:description])))
    end

    desc "update CARD_NUMBER", "Update a card"
    option :title, type: :string
    option :description, type: :string
    def update(card_number)
      render_output(request(:put, "cards/#{card_number}", params: compact_hash(title: options[:title], description: options[:description])))
    end

    desc "delete CARD_NUMBER", "Delete a card"
    def delete(card_number)
      render_output(request(:delete, "cards/#{card_number}"))
    end

    desc "move CARD_NUMBER", "Move a card to another board"
    option :board, type: :string, required: true
    def move(card_number)
      render_output(request(:put, "cards/#{card_number}/board", params: { board_id: options[:board] }))
    end

    desc "close CARD_NUMBER", "Move a card to Done"
    def close(card_number)
      render_output(request(:post, "cards/#{card_number}/closure"))
    end

    desc "reopen CARD_NUMBER", "Reopen a closed card"
    def reopen(card_number)
      render_output(request(:delete, "cards/#{card_number}/closure"))
    end

    desc "postpone CARD_NUMBER", "Move a card to Not Now"
    def postpone(card_number)
      render_output(request(:post, "cards/#{card_number}/not_now"))
    end

    desc "triage CARD_NUMBER", "Move a card from triage into a column"
    option :column, type: :string, required: true
    def triage(card_number)
      render_output(request(:post, "cards/#{card_number}/triage", params: { column_id: options[:column] }))
    end

    desc "watch CARD_NUMBER", "Watch a card"
    def watch(card_number)
      render_output(request(:post, "cards/#{card_number}/watch"))
    end

    desc "unwatch CARD_NUMBER", "Stop watching a card"
    def unwatch(card_number)
      render_output(request(:delete, "cards/#{card_number}/watch"))
    end

    desc "pin CARD_NUMBER", "Pin a card"
    def pin(card_number)
      render_output(request(:post, "cards/#{card_number}/pin"))
    end

    desc "unpin CARD_NUMBER", "Unpin a card"
    def unpin(card_number)
      render_output(request(:delete, "cards/#{card_number}/pin"))
    end

    desc "assign CARD_NUMBER USER_ID", "Toggle assignment for a user on a card"
    def assign(card_number, user_id)
      render_output(request(:post, "cards/#{card_number}/assignments", params: { assignee_id: user_id }))
    end

    desc "self_assign CARD_NUMBER", "Toggle self-assignment on a card"
    def self_assign(card_number)
      render_output(request(:post, "cards/#{card_number}/self_assignment"))
    end

    desc "tag CARD_NUMBER TAG_TITLE", "Toggle a tag on a card"
    def tag(card_number, tag_title)
      render_output(request(:post, "cards/#{card_number}/taggings", params: { tag_title: }))
    end
  end

  class CommentsCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list CARD_NUMBER", "List comments on a card"
    def list(card_number)
      render_output(request(:get, "cards/#{card_number}/comments"))
    end

    desc "get CARD_NUMBER COMMENT_ID", "Fetch a comment"
    def get(card_number, comment_id)
      render_output(request(:get, "cards/#{card_number}/comments/#{comment_id}"))
    end

    desc "create CARD_NUMBER BODY", "Create a comment"
    def create(card_number, body)
      render_output(request(:post, "cards/#{card_number}/comments", params: { body: }))
    end

    desc "update CARD_NUMBER COMMENT_ID BODY", "Update a comment"
    def update(card_number, comment_id, body)
      render_output(request(:put, "cards/#{card_number}/comments/#{comment_id}", params: { body: }))
    end

    desc "delete CARD_NUMBER COMMENT_ID", "Delete a comment"
    def delete(card_number, comment_id)
      render_output(request(:delete, "cards/#{card_number}/comments/#{comment_id}"))
    end
  end

  class StepsCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list CARD_NUMBER", "List steps on a card"
    def list(card_number)
      render_output(request(:get, "cards/#{card_number}/steps"))
    end

    desc "get CARD_NUMBER STEP_ID", "Fetch a step"
    def get(card_number, step_id)
      render_output(request(:get, "cards/#{card_number}/steps/#{step_id}"))
    end

    desc "create CARD_NUMBER CONTENT", "Create a step"
    def create(card_number, content)
      render_output(request(:post, "cards/#{card_number}/steps", params: { content: }))
    end

    desc "update CARD_NUMBER STEP_ID CONTENT", "Update a step"
    def update(card_number, step_id, content)
      render_output(request(:put, "cards/#{card_number}/steps/#{step_id}", params: { content: }))
    end

    desc "delete CARD_NUMBER STEP_ID", "Delete a step"
    def delete(card_number, step_id)
      render_output(request(:delete, "cards/#{card_number}/steps/#{step_id}"))
    end
  end

  class TagsCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list", "List tags"
    def list
      render_output(request(:get, "tags"))
    end
  end

  class UsersCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list", "List users in the current account"
    def list
      render_output(request(:get, "users"))
    end

    desc "get USER_ID", "Fetch a user"
    def get(user_id)
      render_output(request(:get, "users/#{user_id}"))
    end

    desc "update USER_ID", "Update a user"
    option :name, type: :string, required: true
    def update(user_id)
      render_output(request(:put, "users/#{user_id}", params: { name: options[:name] }))
    end

    desc "delete USER_ID", "Delete a user"
    def delete(user_id)
      render_output(request(:delete, "users/#{user_id}"))
    end
  end

  class NotificationsCommand < Thor
    include CLIHelpers
    map "read-all" => :read_all

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list", "List notifications"
    def list
      render_output(request(:get, "notifications"))
    end

    desc "read NOTIFICATION_ID", "Mark a notification as read"
    def read(notification_id)
      render_output(request(:post, "notifications/#{notification_id}/reading"))
    end

    desc "unread NOTIFICATION_ID", "Mark a notification as unread"
    def unread(notification_id)
      render_output(request(:delete, "notifications/#{notification_id}/reading"))
    end

    desc "read_all", "Mark all notifications as read"
    def read_all
      render_output(request(:post, "notifications/bulk_reading"))
    end
  end

  class WebhooksCommand < Thor
    include CLIHelpers

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "list BOARD_ID", "List webhooks on a board"
    def list(board_id)
      render_output(request(:get, "boards/#{board_id}/webhooks"))
    end

    desc "get BOARD_ID WEBHOOK_ID", "Fetch a webhook"
    def get(board_id, webhook_id)
      render_output(request(:get, "boards/#{board_id}/webhooks/#{webhook_id}"))
    end

    desc "create BOARD_ID NAME URL", "Create a webhook"
    option :actions, type: :string, required: true, desc: "Comma-separated subscribed actions"
    def create(board_id, name, url)
      render_output(request(:post, "boards/#{board_id}/webhooks", params: {
        name:,
        url:,
        subscribed_actions: options[:actions].split(",").map(&:strip)
      }))
    end

    desc "update BOARD_ID WEBHOOK_ID", "Update a webhook"
    option :name, type: :string
    option :url, type: :string
    option :actions, type: :string, desc: "Comma-separated subscribed actions"
    def update(board_id, webhook_id)
      render_output(request(:patch, "boards/#{board_id}/webhooks/#{webhook_id}", params: compact_hash(
        name: options[:name],
        url: options[:url],
        subscribed_actions: options[:actions]&.split(",")&.map(&:strip)
      )))
    end

    desc "delete BOARD_ID WEBHOOK_ID", "Delete a webhook"
    def delete(board_id, webhook_id)
      render_output(request(:delete, "boards/#{board_id}/webhooks/#{webhook_id}"))
    end

    desc "activate BOARD_ID WEBHOOK_ID", "Reactivate an inactive webhook"
    def activate(board_id, webhook_id)
      render_output(request(:post, "boards/#{board_id}/webhooks/#{webhook_id}/activation"))
    end
  end

  class CLI < Thor
    include CLIHelpers

    def self.exit_on_failure?
      true
    end

    class_option :profile, type: :string, desc: "CLI profile to use"
    class_option :json, type: :boolean, default: false, desc: "Print JSON output"

    desc "whoami", "Show the active identity and accounts"
    def whoami
      render_output(request(:get, "/my/identity", account_scope: false))
    end

    desc "api METHOD PATH", "Call a raw Fizzy API path"
    option :data, type: :string, desc: "JSON request body"
    option :account_scope, type: :boolean, default: false, desc: "Prefix the current account slug to PATH"
    def api(method, path)
      payload = options[:data] ? parse_json(options[:data]) : nil
      render_output(request(method, path, params: payload, account_scope: options[:account_scope]))
    end

    desc "version", "Print the CLI version"
    def version
      puts VERSION
    end

    desc "auth SUBCOMMAND ...ARGS", "Authentication and profile commands"
    subcommand "auth", AuthCommand

    desc "accounts SUBCOMMAND ...ARGS", "Account discovery commands"
    subcommand "accounts", AccountsCommand

    desc "boards SUBCOMMAND ...ARGS", "Board CRUD commands"
    subcommand "boards", BoardsCommand

    desc "columns SUBCOMMAND ...ARGS", "Column CRUD commands"
    subcommand "columns", ColumnsCommand

    desc "cards SUBCOMMAND ...ARGS", "Card CRUD and action commands"
    subcommand "cards", CardsCommand

    desc "comments SUBCOMMAND ...ARGS", "Comment CRUD commands"
    subcommand "comments", CommentsCommand

    desc "steps SUBCOMMAND ...ARGS", "Checklist step CRUD commands"
    subcommand "steps", StepsCommand

    desc "tags SUBCOMMAND ...ARGS", "Tag read commands"
    subcommand "tags", TagsCommand

    desc "users SUBCOMMAND ...ARGS", "User CRUD commands"
    subcommand "users", UsersCommand

    desc "notifications SUBCOMMAND ...ARGS", "Notification commands"
    subcommand "notifications", NotificationsCommand

    desc "webhooks SUBCOMMAND ...ARGS", "Webhook CRUD commands"
    subcommand "webhooks", WebhooksCommand

    def self.handle_argument_error(command, error, _args, _arity)
      warn error.message
      exit(1)
    end

    def self.handle_no_command_error(command, has_namespace = $thor_runner)
      super
    rescue Thor::Error => error
      warn error.message
      exit(1)
    end
  end
end
