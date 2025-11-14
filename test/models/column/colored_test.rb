require "test_helper"

class Column::ColoredTest < ActiveSupport::TestCase
  test "creates column with default color when color not provided" do
    column = boards(:writebook).columns.create!(name: "New Column")

    assert_equal Column::Colored::DEFAULT_COLOR, column.color
  end

  test "update the column color" do
    columns(:writebook_triage).update!(color: "var(--color-card-3)")

    assert_not_nil columns(:writebook_triage).color
    assert_equal Color.for_value("var(--color-card-3)"), columns(:writebook_triage).color
  end
end
