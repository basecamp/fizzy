require "test_helper"

class FilterPeopleTest < ActionView::TestCase
  include FiltersHelper

  %w[ assignees creators closers ].each do |people|
    test "#{people} offers the current user once with a searchable Me label" do
      Current.with(account: accounts("37s"), user: users(:david)) do
        filter = Filter.new
        filter.public_send(people) << Current.user
        filtering = User::Filtering.new(Current.user, filter)

        render partial: "filters/settings/#{people}", locals: { user_filtering: filtering }

        assert_select "[data-multi-selection-combobox-value='#{Current.user.id}'][aria-checked='true']", count: 1 do
          assert_select "span.overflow-ellipsis", text: "Me"
          assert_select "span.visually-hidden", text: Current.user.name
        end
      end
    end
  end
end
