require "test_helper"

class Command::Ai::ParserTest < ActionDispatch::IntegrationTest
  include CommandTestHelper, VcrTestHelper

  test "the parsed command contains the raw line" do
    result = parse_command "assign @kevin"
    assert_equal "assign @kevin", result.line
  end

  test "parse command strings into a composite command containing the individual commands" do
    result = parse_command "assign @kevin and close"

    assert_instance_of Command::Composite, result
    commands = result.commands

    assert_instance_of Command::Assign, commands.first
    assert_instance_of Command::Close, commands.last
  end

  test "resolve filter string params as ids" do
    result = parse_command "cards assigned to kevin, tagged with #web, in the collection writebook"
    assert_equal 1, result.commands.size

    url = result.commands.first.url
    query_string = URI.parse(url).query
    params = Rack::Utils.parse_nested_query(query_string).with_indifferent_access

    assert_equal [ users(:kevin).id.to_s ], params[:assignee_ids]
    assert_equal [ collections(:writebook).id.to_s ], params[:collection_ids]
    assert_equal [ tags(:web).id.to_s ], params[:tag_ids]
  end
end
