require "test_helper"

class Cards::NavigationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    Current.session = sessions(:david)
  end

  test "returns only the active column's card numbers" do
    get card_navigation_url(cards(:logo)), as: :json

    assert_response :success
    assert_equal cards(:logo, :layout).map(&:number).sort, response.parsed_body["numbers"].sort
    assert_equal columns(:writebook_triage).id, response.parsed_body["column_id"]
    assert_equal "Triage", response.parsed_body["name"]
  end

  test "retains the original column after closing or moving the current card" do
    card = cards(:logo)
    original_column = card.column
    card.triage_into columns(:writebook_review)
    card.close

    get card_navigation_url(card), params: { column_id: original_column.id }, as: :json
    assert_response :success
    assert_equal [ cards(:layout).number ], response.parsed_body["numbers"]
  end

  test "does not expose an inaccessible board" do
    Current.session = sessions(:kevin)
    card = boards(:private).cards.create!(title: "Private card", status: :published)

    get card_navigation_url(card), as: :json
    assert_response :not_found
  end

  test "does not accept a column from another board" do
    Current.session = sessions(:kevin)
    column = boards(:private).columns.create!(name: "Private")

    get card_navigation_url(cards(:logo)), params: { column_id: column.id }, as: :json
    assert_response :not_found
  end
end
