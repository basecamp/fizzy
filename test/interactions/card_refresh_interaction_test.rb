require "test_helper"

class CardRefreshInteractionTest < RailsJsdom::TestCase
  include ActionView::RecordIdentifier

  setup do
    sign_in_as(users(:david))
    Current.user = users(:kevin)
    @card = cards(:layout)
  end

  test "a broadcast refresh shows card changes made elsewhere" do
    visit card_path(@card)
    assert_selector "h1", text: @card.title

    update_card_elsewhere

    assert_selector "h1", text: "Retitled elsewhere"
    assert_text "Description updated elsewhere"
  end

  test "a broadcast refresh preserves an edit in progress" do
    visit card_path(@card)
    click_on @card.title

    within_edit_frame do
      fill_in_lexxy with: "Draft description in progress"
    end

    update_card_elsewhere

    assert_text "changed the title"
    within_edit_frame do
      assert_selector "lexxy-editor", text: "Draft description in progress"
    end
    assert_no_text "Description updated elsewhere"
  end

  test "canceling an edit reveals card changes made elsewhere during the edit" do
    visit card_path(@card)
    click_on @card.title
    within_edit_frame { assert_selector "form" }

    update_card_elsewhere
    assert_text "changed the title"

    send_keys :escape

    assert_selector "h1", text: "Retitled elsewhere"
    assert_text "Description updated elsewhere"
  end

  test "a broadcast refresh shows card changes after an edit is canceled" do
    visit card_path(@card)
    click_on @card.title
    within_edit_frame { assert_selector "form" }

    send_keys :escape
    assert_selector "a.card__title-link", text: @card.title

    update_card_elsewhere

    assert_selector "h1", text: "Retitled elsewhere"
    assert_text "Description updated elsewhere"
  end

  private
    def update_card_elsewhere
      @card.update!(title: "Retitled elsewhere", description: "Description updated elsewhere")
      perform_enqueued_jobs only: Turbo::Streams::BroadcastStreamJob
    end

    def within_edit_frame(&block)
      within "##{dom_id(@card, :edit)}", &block
    end

    def fill_in_lexxy(selector = "lexxy-editor", with:)
      execute_script("document.querySelector(#{selector.to_json}).value = #{with.to_json}")
    end
end
