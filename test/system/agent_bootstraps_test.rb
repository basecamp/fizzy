require "application_system_test_case"

class AgentBootstrapsTest < ApplicationSystemTestCase
  test "account admin can generate an agent bootstrap from a board" do
    sign_in_as(users(:kevin))

    visit board_url(boards(:writebook))
    find("a[href='#{new_board_agent_bootstrap_path(boards(:writebook))}']").click

    assert_current_path new_board_agent_bootstrap_path(boards(:writebook))
    assert_text "Set up an agent for Writebook"

    click_on "Generate setup command"

    assert_current_path %r{/boards/.*/agent_bootstraps/.*}
    assert_text "Agent setup for Writebook"
    assert_field(type: "textarea", with: /fizzy auth bootstrap/)
    assert_text "Copy skill URL"
    assert_text "Copy agent prompt"
    assert_field(with: /agent_bootstrap\/.*\/skill/)
    assert_field(with: /agent_bootstrap\/.*\/claim/)
  end
end
