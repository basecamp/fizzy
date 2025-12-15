# Fix stale account names in jump menu and page titles

## Summary
- Jump menu now updates account names immediately after renaming in account settings
- Page titles reflect renamed accounts correctly

## Problem
When accounts were renamed in settings, the jump menu and page titles displayed stale names. This affected users with multiple accounts - the old name would persist until a full page refresh.

**Symptoms:**
- Account names in jump menu didn't update after rename
- Page titles reverted to old account names, especially on the default board


## Solution
The `fresh_when etag:` arrays were missing account data, so Rails served cached responses even after account changes.

**Changes:**
- `my/menus_controller.rb` - Added `@accounts` instance variable to show action & etag array
- `my/menus/show.html.erb` - Use `@accounts` instead of direct `Current.identity.accounts` call
- `boards_controller.rb` - Added `Current.account` to etag in `show_columns`

## Test plan
- [ ] Rename account in settings
- [ ] Verify jump menu shows new name immediately
- [ ] Verify page titles update correctly on all pages

**New tests:**
- `my/menus_controller_test.rb` - Created new test file for ETag cache invalidation across all menu sections
- `boards_controller_test.rb` - Added test for ETag freshness on account rename
