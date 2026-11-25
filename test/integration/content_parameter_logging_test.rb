require "test_helper"

# What people write and search for stays out of the log: the Started and Parameters lines, which carry the
# request's query and parameters, and for a search the SQL too, where the words are a literal.
class ContentParameterLoggingTest < ActionDispatch::IntegrationTest
  include SearchTestHelper

  setup do
    @board.update!(all_access: true)
    @card = @board.cards.create!(title: "Layout is broken", status: "published", creator: @user)
    untenanted { sign_in_as @user }
  end

  test "search_cards' words are filtered from the search's log, its SQL included" do
    [ :html, :json ].each do |format|
      log = capturing_log { get search_path(q: "allotment", script_name: account_path, format: format) }

      assert_response :success
      assert_equal "[FILTERED]", @controller.request.filtered_parameters["q"]
      assert_match %r{Started GET "/\d+/search(\.\w+)?\?q=\[FILTERED\]"}, log
      assert_match(/search_records/, log, "the search's SQL is logged, so its absence below means something")
      assert_no_match(/allot/i, log, "neither the word nor its stem, which is what MySQL's MATCH carries")
    end
  end

  test "list_cards' terms are filtered from its log, its SQL included" do
    log = capturing_log { get cards_path(script_name: account_path, format: :json), params: { terms: [ "allotment" ] } }

    assert_response :success
    assert_equal "[FILTERED]", @controller.request.filtered_parameters["terms"]
    assert_match(/search_records/, log, "the terms' search SQL is logged, so its absence below means something")
    assert_no_match(/allot/i, log)
  end

  test "a saved filter's terms are kept out of its SQL" do
    log = capturing_log { post filters_path(script_name: account_path), params: { terms: [ "allotment" ] } }

    assert_match(/INSERT INTO [`"]filters[`"]/, log)
    assert_no_match(/allot/i, log)
    assert_equal [ "allotment" ], @user.filters.last.terms
  end

  test "the text the MCP server's writes send is filtered from their parameters and request lines" do
    writes = {
      card_comments_path(@card, script_name: account_path, format: :json) => { comment: { body: "Bring the tiller" } },
      board_cards_path(@board, script_name: account_path, format: :json) => { card: { title: "Lease the orchard", description: "Second harvest" } },
      card_steps_path(@card, script_name: account_path, format: :json) => { step: { content: "Sign the lease" } }
    }

    writes.each do |path, params|
      log = capturing_log { post path, params: params, as: :json }

      assert_response :created
      written = params.values.first
      written.each_key { |field| assert_equal "[FILTERED]", @controller.request.filtered_parameters.dig(params.keys.first.to_s, field.to_s), "#{path} #{field}" }
      request_lines = log.lines.grep(/Started|Parameters:/).join
      assert_match(/Parameters:/, request_lines)
      written.each_value { |text| assert_no_match text, request_lines, path }
    end
  end

  test "a comment's text is kept out of the search index's statements, and is still found" do
    log = capturing_log do
      post card_comments_path(@card, script_name: account_path, format: :json), params: { comment: { body: "Hire an orchardist" } }, as: :json
    end

    assert_response :created
    index_statements = log.lines.grep(/search_records/i)
    assert index_statements.grep(/INSERT|UPDATE|REPLACE/i).any?, "the index write is logged, so its absence below means something"
    assert_no_match(/orchard/i, index_statements.join, "neither the word nor its stem")
    assert Card.mentioning("orchardist", user: @user).exists?(@card.id)
  end

  test "every field the MCP server sends text in is filtered, and keys that merely contain q stay visible" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.env_config["action_dispatch.parameter_filter"])
    fields = %w[ q terms title tag_title description public_description body content name email_address timezone_name ]

    filtered = filter.filter(fields.index_with { "raw-value" }.merge("faq" => "a", "qr" => "b", "search" => { "q" => "c" }))

    fields.each { |field| assert_equal "[FILTERED]", filtered[field], field }
    assert_equal "a", filtered["faq"]
    assert_equal "b", filtered["qr"]
    assert_equal "[FILTERED]", filtered.dig("search", "q")
  end

  private
    def account_path
      "/#{@account.external_account_id}"
    end

    # Everything the request logs at debug, SQL included, as the structured request line records it.
    def capturing_log
      log = StringIO.new
      sink = ActiveSupport::Logger.new(log)
      Rails.logger.broadcast_to(sink)
      level, Rails.logger.level = Rails.logger.level, :debug
      yield
      log.string
    ensure
      Rails.logger.level = level
      Rails.logger.stop_broadcasting_to(sink)
    end
end
