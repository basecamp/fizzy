require "test_helper"

class User::FilteringTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @filter = @user.filters.create!
  end

  test "users_for_assignee_filter sorts selected assignees first" do
    # Create some test users
    alice = @user.account.users.create!(name: "Alice", email_address: "alice@test.com")
    bob = @user.account.users.create!(name: "Bob", email_address: "bob@test.com")
    charlie = @user.account.users.create!(name: "Charlie", email_address: "charlie@test.com")
    
    # Select Bob and Charlie as assignees
    @filter.assignees = [charlie, bob]
    @filter.save!
    
    filtering = User::Filtering.new(@user, @filter)
    result = filtering.users_for_assignee_filter
    
    # Selected users (Bob, Charlie) should appear first, both alphabetically sorted
    assert_equal "Bob", result[0].name
    assert_equal "Charlie", result[1].name
    
    # Alice (unselected) should appear after selected users
    assert_equal "Alice", result.find { |u| u.name == "Alice" }.name
    assert result.index { |u| u.name == "Alice" } > 1, "Unselected user should appear after selected users"
  end

  test "users_for_creator_filter sorts selected creators first" do
    alice = @user.account.users.create!(name: "Alice", email_address: "alice@test.com")
    bob = @user.account.users.create!(name: "Bob", email_address: "bob@test.com")
    
    @filter.creators = [bob]
    @filter.save!
    
    filtering = User::Filtering.new(@user, @filter)
    result = filtering.users_for_creator_filter
    
    assert_equal "Bob", result.first.name
  end

  test "users_for_closer_filter sorts selected closers first" do
    alice = @user.account.users.create!(name: "Alice", email_address: "alice@test.com")
    bob = @user.account.users.create!(name: "Bob", email_address: "bob@test.com")
    
    @filter.closers = [alice]
    @filter.save!
    
    filtering = User::Filtering.new(@user, @filter)
    result = filtering.users_for_closer_filter
    
    assert_equal "Alice", result.first.name
  end

  test "users method returns all users alphabetically without selection sorting" do
    filtering = User::Filtering.new(@user, @filter)
    result = filtering.users
    
    # Should just be alphabetical, no selection sorting
    names = result.map(&:name)
    assert_equal names.sort, names, "Users should be alphabetically sorted"
  end
end
