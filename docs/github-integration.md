# GitHub Integration

Fizzy's GitHub integration automatically creates and updates Fizzy cards when GitHub pull requests and issues change. This is a one-way sync from GitHub to Fizzy.

## Features

- **Automatic Card Creation**: New pull requests and issues in GitHub automatically create cards in Fizzy
- **Real-time Updates**: Changes to PR/issue titles, descriptions, and states sync to Fizzy
- **Comment Syncing**: GitHub comments and PR reviews appear as Fizzy card comments
- **Flexible Configuration**: Choose which event types to sync per repository
- **Board-Level Setup**: Each board can connect to one or more GitHub repositories

## Supported Events

### Pull Requests
- Opened: Creates a new Fizzy card
- Edited: Updates the card title and description
- Closed: Marks the card as "Done" with a comment
- Merged: Marks the card as "Done" with a "Merged on GitHub" comment
- Reopened: Reopens the card if it was previously closed

### Issues
- Opened: Creates a new Fizzy card
- Edited: Updates the card title and description
- Closed: Marks the card as "Done" with a comment
- Reopened: Reopens the card if it was previously closed

### Comments
- Issue comments and PR review comments are added to the corresponding Fizzy card
- Comments include the GitHub username and a link back to GitHub

### Reviews
- PR reviews appear as comments on the Fizzy card
- Review state (approved, changes requested, commented) is included

## Setup Instructions

### 1. Add GitHub Integration to Your Board

1. Navigate to your board settings
2. Click on "GitHub Integrations"
3. Click "Add GitHub Repository"
4. Enter the repository name in the format `owner/repo` (e.g., `basecamp/fizzy`)
5. Choose which events to sync (all are enabled by default):
   - Pull Requests
   - Issues
   - Comments
   - Reviews
6. Click "Create GitHub Integration"

### 2. Configure GitHub Webhook

After creating the integration in Fizzy, you'll see the webhook URL and secret. Now configure the webhook in your GitHub repository:

1. Go to your GitHub repository
2. Click **Settings** → **Webhooks** → **Add webhook**
3. Configure the webhook with the following settings:

   - **Payload URL**: Copy the webhook URL from Fizzy
   - **Content type**: Select `application/json`
   - **Secret**: Copy the webhook secret from Fizzy
   - **SSL verification**: Enable SSL verification
   - **Events**: Select "Let me select individual events" and check the events you want to sync:
     - Pull requests (if enabled in Fizzy)
     - Issues (if enabled in Fizzy)
     - Issue comments (if comments enabled in Fizzy)
     - Pull request review comments (if comments enabled in Fizzy)
     - Pull request reviews (if reviews enabled in Fizzy)
   - **Active**: Check this box

4. Click **Add webhook**

### 3. Test the Integration

1. Create a new pull request or issue in your GitHub repository
2. Check your Fizzy board - a new card should appear within a few seconds
3. Try editing the PR/issue title or adding a comment to verify syncing works

### 4. Monitor Webhook Deliveries

You can monitor webhook deliveries on the integration detail page in Fizzy:

1. Go to your board's GitHub Integrations page
2. Click on the integration you want to monitor
3. Scroll down to "Recent Deliveries" to see the last 20 webhook deliveries
4. Each delivery shows:
   - Event type (pull_request, issues, etc.)
   - State (pending, processed, errored)
   - Time received
   - Error message (if failed)

## Account-Level Settings

Account administrators can disable specific event types globally for all integrations:

1. Go to Account Settings
2. Click "GitHub Settings"
3. Uncheck any event types you want to disable across all boards

Note: Account-level settings override board-level settings. If you disable pull requests at the account level, no integrations will sync pull requests, even if they have it enabled.

## How It Works

### Card Creation

When a PR or issue is opened in GitHub:
1. Fizzy receives the webhook
2. Creates a new card with the PR/issue title as the card title
3. Sets the card description to the PR/issue body
4. Links the card to the GitHub item for future updates
5. The card is created by the account's system user

### Card Updates

When a PR or issue is edited:
1. Fizzy finds the existing card linked to that GitHub item
2. Updates the card title and/or description to match GitHub
3. Adds a comment noting what changed

### Comments

GitHub comments are added to Fizzy cards with:
- The GitHub username of the commenter
- The comment body
- A link back to the comment on GitHub

### Closing Cards

When a PR is merged or closed, or an issue is closed:
1. Fizzy marks the card as "Done"
2. Adds an automatic comment explaining why (e.g., "Merged on GitHub" or "Closed on GitHub")

### Security

- All webhook requests are authenticated using HMAC-SHA256 signatures
- Each integration has a unique webhook secret
- Invalid signatures are rejected
- All data is scoped to your account for multi-tenant security

## Troubleshooting

### Cards aren't being created

1. Check that the integration is active (not deactivated)
2. Verify the webhook is configured correctly in GitHub
3. Check recent deliveries for error messages
4. Ensure the event type is enabled both in the integration settings and account settings
5. Check GitHub's webhook delivery page for failed deliveries

### Webhook signature verification failed

1. Double-check that you copied the webhook secret exactly from Fizzy to GitHub
2. Make sure you're using the correct webhook URL (each integration has a unique URL)
3. Try deleting and recreating the webhook in GitHub

### Some events sync but others don't

1. Check the integration settings - ensure all desired event types are enabled
2. Check account-level GitHub settings - these override integration settings
3. Verify in GitHub webhook settings that all event types are selected

### Old deliveries cluttering the view

Delivery records older than 7 days are automatically cleaned up. You don't need to do anything.

## Deactivating an Integration

To temporarily stop syncing without deleting the integration:

1. Go to the integration detail page
2. Click "Deactivate"
3. Webhooks will still be received but will be ignored
4. Click "Activate" to resume syncing

## Deleting an Integration

To permanently remove a GitHub integration:

1. Go to the integration detail page
2. Click "Delete integration"
3. Confirm the deletion
4. **Important**: This does NOT delete the webhook from GitHub. You should also delete the webhook in your GitHub repository settings to stop receiving webhook requests.

## Limitations

- **One-way sync only**: Changes in Fizzy do not sync back to GitHub
- **No user mapping**: Cards are created by the system user, not by matching GitHub users to Fizzy users
- **One board per integration**: Each integration connects one repository to one board
- **No branch filtering**: All PRs are synced regardless of branch
- **No label syncing**: GitHub labels are not synced to Fizzy tags
