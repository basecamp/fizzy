require "test_helper"

class Card::EntropicTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "auto_close_at uses the period defined in the account by default" do
    freeze_time

    entropy_configurations(:writebook_collection).destroy
    entropy_configurations("37s_account").reload.update! auto_close_period: 456.days
    cards(:layout).update! last_active_at: 2.day.ago
    assert_equal (456 - 2).days.from_now, cards(:layout).entropy.auto_clean_at
  end

  test "auto_close_at infers the period from the collection when present" do
    freeze_time

    entropy_configurations(:writebook_collection).update! auto_close_period: 123.days
    cards(:layout).update! last_active_at: 2.day.ago
    assert_equal (123 - 2).days.from_now, cards(:layout).entropy.auto_clean_at
  end

  test "auto_reconsider_at uses the period defined in the account by default" do
    freeze_time

    cards(:layout).engage
    entropy_configurations(:writebook_collection).destroy
    entropy_configurations("37s_account").reload.update! auto_reconsider_period: 456.days
    cards(:layout).update! last_active_at: 2.day.ago
    assert_equal (456 - 2).days.from_now, cards(:layout).entropy.auto_clean_at
  end

  test "auto_reconsider_at infers the period from the collection when present" do
    freeze_time

    cards(:layout).engage
    entropy_configurations(:writebook_collection).update! auto_reconsider_period: 123.days
    cards(:layout).update! last_active_at: 2.day.ago
    assert_equal (123 - 2).days.from_now, cards(:layout).entropy.auto_clean_at
  end

  test "auto close all due using the default account entropy configuration" do
    cards(:logo, :shipping).each(&:reconsider)
    entropy_configurations(:writebook_collection).destroy

    cards(:logo).update!(last_active_at: 1.day.ago - entropy_configurations("37s_account").auto_close_period)
    cards(:shipping).update!(last_active_at: 1.day.from_now - entropy_configurations("37s_account").auto_close_period)

    assert_difference -> { Card.closed.count }, +1 do
      Card.auto_close_all_due
    end

    assert cards(:logo).reload.closed?
    assert cards(:logo).events.last.action.card_auto_closed?
    assert_not cards(:shipping).reload.closed?
    assert_not cards(:shipping).events.last.action.card_auto_closed?
  end

  test "auto close all due using entropy configuration defined at the collection level" do
    cards(:logo, :shipping).each(&:reconsider)

    cards(:logo).update!(last_active_at: 1.day.ago - entropy_configurations(:writebook_collection).auto_close_period)
    cards(:shipping).update!(last_active_at: 1.day.from_now - entropy_configurations(:writebook_collection).auto_close_period)

    assert_difference -> { Card.closed.count }, +1 do
      Card.auto_close_all_due
    end

    assert cards(:logo).reload.closed?
    assert_not cards(:shipping).reload.closed?
  end

  test "closing soon scope" do
    cards(:logo, :shipping).each(&:published!).each(&:reconsider)

    cards(:logo).update!(last_active_at: entropy_configurations(:writebook_collection).auto_close_period.seconds.ago + 2.days)
    cards(:shipping).update!(last_active_at: entropy_configurations(:writebook_collection).auto_close_period.seconds.ago - 2.days)

    assert_includes Card.closing_soon, cards(:logo)
    assert_not_includes Card.closing_soon, cards(:shipping)
  end

  test "auto consider all stagnated using the default account entropy configuration" do
    travel_to Time.current

    cards(:logo, :shipping).each(&:engage)
    entropy_configurations(:writebook_collection).destroy

    cards(:logo).update!(last_active_at: 1.day.ago - entropy_configurations("37s_account").auto_close_period)
    cards(:shipping).update!(last_active_at: 1.day.from_now - entropy_configurations("37s_account").auto_close_period)

    assert_difference -> { Card.considering.count }, +1 do
      Card.auto_reconsider_all_stagnated
    end

    assert cards(:shipping).reload.doing?
    assert cards(:logo).reload.considering?
    assert_equal Time.current, cards(:logo).last_active_at
  end

  test "auto_reconsider_all_stagnated includes cards in doing and on_deck" do
    travel_to Time.current

    cards(:logo, :shipping).each(&:engage)

    cards(:logo).update!(last_active_at: 1.day.ago - entropy_configurations("writebook_collection").auto_close_period)
    cards(:shipping).update!(last_active_at: 1.day.from_now - entropy_configurations("writebook_collection").auto_close_period)

    assert_difference -> { Card.considering.count }, +1 do
      Card.auto_reconsider_all_stagnated
    end

    assert cards(:shipping).reload.doing?
    assert cards(:logo).reload.considering?
    assert_equal Time.current, cards(:logo).last_active_at
  end

  test "falling back scope" do
    travel_to Time.current

    cards(:logo, :shipping).each(&:engage)

    cards(:logo).update!(last_active_at: 1.day.ago - entropy_configurations("writebook_collection").auto_close_period)
    cards(:shipping).update!(last_active_at: 1.day.from_now - entropy_configurations("writebook_collection").auto_close_period)

    assert_includes Card.falling_back_soon, cards(:shipping)
    assert_not_includes Card.falling_back_soon, cards(:logo)
  end
end
