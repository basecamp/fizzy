require "test_helper"

class My::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get my_pins_path

    assert_response :success
    assert_select "div", text: /#{users(:kevin).pins.first.card.title}/
  end

  test "index as JSON" do
    expected_ids = users(:kevin).pins.ordered.pluck(:card_id)

    get my_pins_path(format: :json)

    assert_response :success
    assert_equal expected_ids.count, @response.parsed_body.count
    assert_equal expected_ids, @response.parsed_body.map { |card| card["id"] }
  end

  test "index skips pins on a board the pinner cannot access" do
    logout_and_sign_in_as :david
    cards(:logo).pin_by(users(:david))
    secret_column = move_to_private_board cards(:logo)

    get my_pins_path

    assert_response :success
    assert_no_match boards(:private).name, @response.body
    assert_no_match secret_column.name, @response.body
  end

  test "index as JSON skips pins on a board the pinner cannot access" do
    logout_and_sign_in_as :david
    cards(:logo).pin_by(users(:david))
    cards(:layout).pin_by(users(:david))
    move_to_private_board cards(:logo)

    get my_pins_path(format: :json)

    assert_response :success
    assert_equal [ cards(:layout).id ], @response.parsed_body.map { |card| card["id"] }
    assert_no_match boards(:private).name, @response.body
  end

  test "index as JSON skips pins after the pinner loses access to the board" do
    accesses(:writebook_kevin).destroy

    get my_pins_path(format: :json)

    assert_response :success
    assert_empty @response.parsed_body
  end

  test "index as JSON keeps pins on a board the pinner can access" do
    move_to_private_board cards(:logo)

    get my_pins_path(format: :json)

    assert_response :success
    assert_includes @response.parsed_body.map { |card| card["id"] }, cards(:logo).id
  end

  private
    def move_to_private_board(card)
      with_current_user(:kevin) do
        boards(:private).columns.create!(name: "Ultrasecret", color: "var(--color-card-1)").tap do
          card.update!(board: boards(:private))
        end
      end
    end
end
