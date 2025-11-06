require "test_helper"

class Card::EntropicTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "auto_postpone_at uses the period defined in the account by default" do
    freeze_time

    entropies(:writebook_board).destroy
    entropies("37s_account").reload.update! auto_postpone_period: 456.days
    cards(:layout).update! last_active_at: 2.day.ago
    assert_equal (456 - 2).days.from_now, cards(:layout).entropy.auto_clean_at
  end

  test "auto_postpone_at infers the period from the board when present" do
    freeze_time

    entropies(:writebook_board).update! auto_postpone_period: 123.days
    cards(:layout).update! last_active_at: 2.day.ago
    assert_equal (123 - 2).days.from_now, cards(:layout).entropy.auto_clean_at
  end

  test "auto postpone all due using the default account entropy" do
    entropies(:writebook_board).destroy

    cards(:logo).update!(last_active_at: 1.day.ago - entropies("37s_account").auto_postpone_period)
    cards(:shipping).update!(last_active_at: 1.day.from_now - entropies("37s_account").auto_postpone_period)

    assert_difference -> { Card.postponed.count }, +1 do
      Card.auto_postpone_all_due
    end

    assert cards(:logo).reload.postponed?
    assert_equal User.system, cards(:logo).postponed_by
    assert_not cards(:shipping).reload.postponed?
  end

  test "auto postpone all due using entropy defined at the board level" do
    cards(:logo).update!(last_active_at: 1.day.ago - entropies(:writebook_board).auto_postpone_period)
    cards(:shipping).update!(last_active_at: 1.day.from_now - entropies(:writebook_board).auto_postpone_period)

    assert_difference -> { Card.postponed.count }, +1 do
      Card.auto_postpone_all_due
    end

    assert cards(:logo).reload.postponed?
    assert_not cards(:shipping).reload.postponed?
  end

  test "postponing soon scope" do
    cards(:logo, :shipping).each(&:published!)

    cards(:logo).update!(last_active_at: entropies(:writebook_board).auto_postpone_period.seconds.ago + 2.days)
    cards(:shipping).update!(last_active_at: entropies(:writebook_board).auto_postpone_period.seconds.ago - 2.days)

    assert_includes Card.postponing_soon, cards(:logo)
    assert_not_includes Card.postponing_soon, cards(:shipping)
  end
end
