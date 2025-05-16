require "test_helper"

class Command::GoToCardTest < ActionDispatch::IntegrationTest
  include CommandTestHelper

  include VcrTestHelper

  vcr_record!

  setup do
    @card = cards(:logo)
  end

  test "redirect to the card perma" do
    result = execute_command "#{@card.id}"

    assert_equal @card, result.url
  end

  test "result in a regular search if the card does not exist" do
    command = parse_command "123"

    puts command.commands.first.inspect
    assert command.valid?

    result = command.execute
    assert_equal cards_path(indexed_by: "newest", terms: [ "123" ]), result.url
  end
end
