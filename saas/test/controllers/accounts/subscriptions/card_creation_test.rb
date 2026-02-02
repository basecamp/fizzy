require "test_helper"

class Account::Subscriptions::CardCreationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mike
  end

  # Nearing limits - shown in card creation footer

  test "admin sees nearing card limit notice" do
    accounts(:initech).update_column(:cards_count, 950)

    get card_draft_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :success
    assert_match /upgrade to unlimited/i, response.body
  end

  test "admin sees nearing storage limit notice" do
    Account.any_instance.stubs(:bytes_used).returns(600.megabytes)

    get card_draft_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :success
    assert_match /upgrade to get more/i, response.body
  end

  # Exceeding limits - shown instead of create buttons

  test "admin sees exceeding card limit notice" do
    accounts(:initech).update_column(:cards_count, 1001)

    get card_draft_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :success
    assert_match /you’ve used your.*free cards/i, response.body
  end

  test "admin sees exceeding storage limit notice" do
    Account.any_instance.stubs(:bytes_used).returns(1.1.gigabytes)

    get card_draft_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :success
    assert_match /you’ve run out of.*free storage/i, response.body
  end

  # Paid accounts under limits - no notices

  test "paid account under limits sees no notices" do
    logout_and_sign_in_as :kevin

    accounts(:"37s").subscription.update!(plan: Plan.paid, status: :active)

    get card_path(cards(:layout), script_name: accounts(:"37s").slug)

    assert_response :success
    assert_no_match /upgrade/i, response.body
    assert_no_match /you’ve used your/i, response.body
  end

  # Comped accounts under limits - no notices

  test "comped account under limits sees no notices" do
    accounts(:initech).comp

    get card_draft_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :success
    assert_no_match /upgrade/i, response.body
    assert_no_match /you’ve used your/i, response.body
  end
end
