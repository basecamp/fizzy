# frozen_string_literal: true

namespace :soak do
  desc "Soak test: run traffic while monitoring thread count and RSS"
  task test: :environment do
    require "net/http"

    base_url = ENV.fetch("FIZZY_URL", "http://fizzy.localhost:3006")
    rounds   = ENV.fetch("ROUNDS", 500).to_i
    delay    = ENV.fetch("DELAY", 0.3).to_f
    sample_interval = ENV.fetch("SAMPLE_EVERY", 10).to_i

    identity = Identity.find_by!(email_address: ENV.fetch("FIZZY_USER", "dingsdax@sentry.io"))
    account  = identity.users.first!.account
    session  = identity.sessions.create!(user_agent: "soak-test", ip_address: "127.0.0.1")

    fake_request = ActionDispatch::Request.new(Rails.application.env_config.merge("rack.input" => StringIO.new))
    fake_jar = ActionDispatch::Cookies::CookieJar.build(fake_request, {})
    fake_jar.signed[:session_token] = session.signed_id
    cookie = "session_token=#{fake_jar[:session_token]}"

    uri_base = URI(base_url)
    http = Net::HTTP.new(uri_base.host, uri_base.port)
    http.open_timeout = 5
    http.read_timeout = 10

    puma_pids = `pgrep -f 'puma'`.strip.split("\n").map(&:to_i).reject(&:zero?)
    if puma_pids.empty?
      puts "ERROR: No puma processes found. Start the server first with bin/dev"
      exit 1
    end
    puts "Monitoring PIDs: #{puma_pids.join(', ')}"

    sample = lambda do |samples, round, start_time, errors|
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(1)
      total_rss = 0
      total_threads = 0

      puma_pids.each do |pid|
        rss = `ps -o rss= -p #{pid} 2>/dev/null`.strip.to_i / 1024
        threads = `ps -M -p #{pid} 2>/dev/null | wc -l`.strip.to_i - 1
        total_rss += rss
        total_threads += threads
      rescue
        nil
      end

      entry = { round: round, elapsed: elapsed, rss_mb: total_rss, threads: total_threads, errors: errors }
      samples << entry

      status = if samples.size >= 2
        prev = samples[-2]
        rss_d = total_rss - prev[:rss_mb]
        thr_d = total_threads - prev[:threads]
        "RSS #{rss_d >= 0 ? '+' : ''}#{rss_d}MB, Threads #{thr_d >= 0 ? '+' : ''}#{thr_d}"
      else
        "baseline"
      end

      printf "%-6d  %-8s  %-10d  %-10d  %-8d  %s\n", round, "#{elapsed}s", total_rss, total_threads, errors, status
    end

    Current.set(account: account, session: session) do
      user   = Current.session.identity.users.find_by!(account: account)
      boards = Board.where(account: account).to_a

      if boards.empty?
        puts "No boards found — run db:seed first."
        exit 1
      end

      boards.each do |board|
        if board.columns.empty?
          %w[Backlog Doing Done].each { |name| board.columns.create!(name: name) }
        end
      end

      account_path = "/#{account.external_account_id}"

      samples = []
      errors = 0
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      puts
      puts "Soak test: #{rounds} rounds, #{delay}s delay, sampling every #{sample_interval} rounds"
      puts "=" * 80
      printf "%-6s  %-8s  %-10s  %-10s  %-8s  %s\n", "Round", "Elapsed", "RSS (MB)", "Threads", "Errors", "Status"
      puts "-" * 80

      sample.call(samples, 0, start_time, errors)

      pending_closures = []

      rounds.times do |round|
        r = round + 1

        endpoints = [
          "#{account_path}/events",
          "/up",
          "#{account_path}/boards/#{boards.sample.id}",
          "#{account_path}/notifications",
        ]

        endpoints.each do |path|
          req = Net::HTTP::Get.new(path)
          req["Cookie"] = cookie
          req["Host"] = uri_base.host
          req["X-Request-Start"] = "t=#{Time.now.to_f}"
          http.request(req)
        rescue => e
          errors += 1
          $stderr.puts "  HTTP error on #{path}: #{e.class} #{e.message}"
        end

        board = boards.sample
        begin
          card = board.cards.create!(
            title: "Soak #{r} — #{Time.now.strftime('%H:%M:%S')}",
            description: "Soak test",
            creator: user,
            status: :published
          )
          card.comments.create!(body: "Soak comment #{r}", creator: user)

          columns = board.columns.to_a
          if columns.size >= 2
            card.update!(column: columns.first)
            card.update!(column: columns.last)
          end

          if r % 4 == 0
            pending_closures << { card: card, close_at: r + rand(2..8) }
          end

          pending_closures.select { |c| c[:close_at] <= r }.each do |entry|
            entry[:card].close
          end
          pending_closures.reject! { |c| c[:close_at] <= r }
        rescue => e
          errors += 1
          $stderr.puts "  Model error: #{e.class} #{e.message}"
        end

        sample.call(samples, r, start_time, errors) if r % sample_interval == 0

        sleep delay
      end

      pending_closures.each { |entry| entry[:card].close rescue nil }

      sample.call(samples, rounds, start_time, errors)

      puts "=" * 80
      puts
      puts "SUMMARY"
      puts "-" * 40

      if samples.size >= 2
        first = samples.first
        last = samples.last
        rss_delta = last[:rss_mb] - first[:rss_mb]
        thread_delta = last[:threads] - first[:threads]
        post_warmup = samples.select { |s| s[:round] >= 50 }
        thread_stable = post_warmup.all? { |s| (s[:threads] - post_warmup.first[:threads]).abs <= 2 }

        puts "Duration:       #{last[:elapsed]}s"
        puts "Rounds:         #{rounds}"
        puts "Errors:         #{errors}"
        puts "RSS start:      #{first[:rss_mb]} MB"
        puts "RSS end:        #{last[:rss_mb]} MB"
        puts "RSS delta:      #{rss_delta >= 0 ? '+' : ''}#{rss_delta} MB"
        puts "Threads start:  #{first[:threads]}"
        puts "Threads end:    #{last[:threads]}"
        puts "Thread delta:   #{thread_delta >= 0 ? '+' : ''}#{thread_delta}"
        puts

        if thread_stable
          puts "OK: Thread count stable (post-warmup variance <= 2)"
        else
          puts "WARNING: Thread count unstable post-warmup — possible thread leak"
        end

        if errors > 0
          puts "WARNING: #{errors} errors during test"
        else
          puts "OK: Zero errors"
        end
      end

      session.destroy
      puts
      puts "Done."
    end
  end
end
