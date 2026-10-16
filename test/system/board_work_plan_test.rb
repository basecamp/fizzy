require "application_system_test_case"

class BoardWorkPlanTest < ApplicationSystemTestCase
  setup do
    @board = boards(:writebook)
    @board.update!(work_planning_time_limit_in_seconds: 5)

    @card = with_current_user(:kevin) do
      @board.cards.create!(title: "Plan this card", column: columns(:writebook_triage), status: :published)
    end
  end

  test "an admin previews the plan and approves it" do
    sign_in_as users(:kevin)
    visit board_path(@board)

    click_on "Assign work"
    @board.users.active.where.not(id: users(:kevin).id).each { |user| uncheck user.name }
    click_on "Review plan"

    # The solver runs while the frame loads, so wait past the default timeout.
    assert_selector ".work-plan__summary", wait: 15
    assert_selector ".work-plan__person-name"
    assert_text "Plan this card"
    assert_selector ".work-plan__person-name", text: users(:kevin).name

    click_on "Approve and assign"

    assert_text "Work plan applied"
    assert @card.reload.assigned_to?(users(:kevin))
  end

  test "a board with 200 members has a bounded searchable chooser" do
    now = Time.current
    extra_users = Array.new(200 - @board.users.active.count) do |number|
      { id: ActiveRecord::Type::Uuid.generate, account_id: @board.account_id,
        name: "Planner member #{number}", role: "member", created_at: now, updated_at: now }
    end
    User.insert_all!(extra_users)
    Access.insert_all!(extra_users.map do |user|
      { id: ActiveRecord::Type::Uuid.generate, account_id: @board.account_id,
        board_id: @board.id, user_id: user.fetch(:id), created_at: now, updated_at: now }
    end)

    sign_in_as users(:kevin)
    visit board_path(@board)
    click_on "Assign work"
    assert_selector ".work-plan__team"

    assert_equal 200, page.evaluate_script("document.querySelectorAll('.work-plan__members li').length")
    assert_operator page.evaluate_script("document.querySelector('.work-plan__members').scrollHeight"), :>,
      page.evaluate_script("document.querySelector('.work-plan__members').clientHeight")

    fill_in "Filter…", with: extra_users.last.fetch(:name)

    assert_selector ".work-plan__members li:not([hidden])", count: 1, text: extra_users.last.fetch(:name)
    assert_equal "post", page.evaluate_script("document.querySelector('.work-plan__team').method")
  end
end
