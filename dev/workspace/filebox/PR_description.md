# Fix stale account names in jump menu and page titles
In the jump menu (and page titles) a caching bug is causing 'stale' data to be displayed when updating some of the underlying data.

## Fix Summary
- Jump menu now updates account names immediately after renaming in account settings.
- Page titles reflect renamed accounts correctly.

## Former Behaviour

When accounts are renamed in account settings, with a user (identity) having multiple accounts. The following behaviour occurs:

- **Accounts** listed in the jump menu do not update their names.
- **Page Titles** will sometimes revert back to original account names, especially on the default board. When navigating to a different page the page title will use the correct account name.

## Bug fix
Upon investigation, I found that the `fresh_when etag: []` in the `my/menus_controller.rb` did not have an account variable within the array to trigger freshness when accounts change. The `my/menu/show.html.erb` was using a direct call to `Current.identity.accounts` to load accounts into the menu. The fix was to create a `@accounts` variable in the controller, then calling the instance variable in the `etag:` and the `show` page.

Also calling `Current.account` in the etag in `show_columns` method in `boards_controller.rb` refreshed the board when account names changed. This then is injected through the `@page_title` variable into the `page_title_tag` helper, allowing the account name in the page title to update correctly.

## Files and Logic changes
In `my/menus_controller.rb` - Added `@accounts` instance variable to the `show` action & etag array

In `my/menu/show.html.erb` - Use `@accounts` instead of direct `Current.identity.accounts` call

In `boards_controller.rb` - Update the etag array to include `Current.account` 

### Optional - Bust cache removal
In `my/menus/_accounts.html.erb` - Remove the `Bust cache` comment, it should be now reduntant. Although I do not know internal reasoning, so I won't remove it in the PR. 
```diff
<% if accounts.many? %>
  <% cache [ Current.identity, accounts, Current.account ] do %>
    <%= collapsible_nav_section "Accounts" do %>
-     <%# Bust cache 1 Dec 2025 %>
      <% accounts.each do |account| %>
        ...
      <% end %>
    <% end %>
  <% end %>
<% end %>
```

### Testing
Two tests have been created to enhance this fix and prevent future regressions.

`my/menus_controller_test.rb` - Was not present as a test file, so I have created one. 
- Testing the basic show action, as per other tests.
- Testing each instance variable in the etag array. This protects the menu from having stale data. As each variable "represents" a different section of the menu.

`boards_controller_test.rb` - Testing the `show_columns` action only, this test is slightly different as we are only protecting the page title from stale data. So therefore only tests etag freshness when an account rename occurs.
