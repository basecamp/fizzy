# frozen_string_literal: true

namespace :traffic do
  desc "Generate sustained traffic against the running Fizzy server to populate Sentry dashboards"
  task generate: :environment do
    require "net/http"

    base_url = ENV.fetch("FIZZY_URL", "http://fizzy.localhost:3006")
    rounds   = ENV.fetch("ROUNDS", 20).to_i
    delay    = ENV.fetch("DELAY", 1.0).to_f

    identity = Identity.find_by!(email_address: ENV.fetch("FIZZY_USER", "dingsdax@sentry.io"))
    account  = identity.users.first!.account
    session  = identity.sessions.create!(user_agent: "traffic-generator", ip_address: "127.0.0.1")

    # Generate a properly signed session cookie using Rails' own cookie jar
    fake_request = ActionDispatch::Request.new(Rails.application.env_config.merge("rack.input" => StringIO.new))
    fake_jar = ActionDispatch::Cookies::CookieJar.build(fake_request, {})
    fake_jar.signed[:session_token] = session.signed_id
    cookie = "session_token=#{fake_jar[:session_token]}"

    Current.set(account: account, session: session) do
      user   = Current.session.identity.users.find_by!(account: account)
      boards = Board.where(account: account).to_a

      if boards.empty?
        puts "No boards found — run db:seed first."
        exit 1
      end

      account_path = "/#{account.external_account_id}"
      uri_base = URI(base_url)
      http = Net::HTTP.new(uri_base.host, uri_base.port)

      puts "Generating traffic: #{rounds} rounds, #{delay}s delay"
      puts "  Target: #{base_url}"
      puts "  User:   #{user.name} (#{identity.email_address})"
      puts "  Boards: #{boards.map(&:name).join(', ')}"
      puts

      rounds.times do |round|
        print "Round #{round + 1}/#{rounds}: "

        # ── HTTP requests (generates request traces, puma metrics, GVL metrics) ──
        endpoints = [
          "#{account_path}/events",                          # events index
          "/up",                                             # health check
          "#{account_path}/boards/#{boards.sample.id}",     # board show
          "#{account_path}/notifications",                   # notifications index
        ]

        endpoints.each do |path|
          req = Net::HTTP::Get.new(path)
          req["Cookie"] = cookie
          req["Host"] = uri_base.host
          req["X-Request-Start"] = "t=#{Time.now.to_f}" # triggers queue_time_metric
          res = http.request(req)
          print "#{path}→#{res.code} "
        end

        # ── Model operations (generates Sentry business metrics via callbacks) ──
        board = boards.sample

        # Create a card
        card = board.cards.create!(
          title: "Traffic card #{round + 1} — #{Time.now.strftime('%H:%M:%S')}",
          description: "Auto-generated for dashboard demo",
          creator: user,
          status: :published
        )
        print "card+ "

        # Add a comment
        card.comments.create!(
          body: "Auto-comment round #{round + 1}",
          creator: user
        )
        print "comment+ "

        # Move card to a column (if columns exist)
        if (column = board.columns.sample)
          card.update!(column: column)
          print "move→#{column.name} "
        end

        # Occasionally close a card
        if round % 4 == 0
          card.close
          print "closed "
        end

        puts
        sleep delay
      end

      puts
      puts "Done. #{rounds} rounds completed."
      puts "Check Sentry for incoming events and metrics."

      # Clean up the session
      session.destroy
    end
  end
end
