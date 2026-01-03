# Slack Emoji Reaction Actions

This guide explains how to set up and use Slack emoji reactions to automatically perform actions on Fizzy cards.

## Overview

When a Slack message creates a card in Fizzy, you can react to that message with specific emojis to trigger actions like moving the card to a different column, closing it, or postponing it. This allows you to manage your Fizzy cards directly from Slack without switching contexts.

## Prerequisites

1. A Slack workspace with admin access
2. A Fizzy board with columns configured
3. A Slack integration already set up on your board

## Step 1: Create a Slack App

1. Go to [https://api.slack.com/apps](https://api.slack.com/apps)
2. Click **"Create New App"** → **"From scratch"**
3. Name your app (e.g., "Fizzy Integration")
4. Select your workspace
5. Click **"Create App"**

## Step 2: Configure Event Subscriptions

1. In your Slack app settings, go to **"Event Subscriptions"**
2. Toggle **"Enable Events"** to ON
3. You'll need to add your Request URL later (after setting up the integration in Fizzy)

### Required Event Scopes

Under **"Subscribe to bot events"**, add these events:
- `message.channels` - Messages posted to public channels
- `reaction_added` - Emoji reactions added to messages

4. Click **"Save Changes"**

## Step 3: Get Your Signing Secret

1. In your Slack app settings, go to **"Basic Information"**
2. Scroll to **"App Credentials"**
3. Copy the **"Signing Secret"** (you'll need this in Step 4)

## Step 4: Set Up Integration in Fizzy

1. In Fizzy, navigate to your board
2. Click **Settings** → **Webhooks**
3. Under **"Incoming Webhooks"**, click **"Manage Slack Integrations"**
4. Click **"Add Channel"**
5. Fill in the form:
   - **Channel ID**: Your Slack channel ID (see "Finding Your Channel ID" below)
   - **Channel Name**: The channel name without # (e.g., "general")
   - **Workspace Domain**: Your Slack workspace domain (e.g., "mycompany")
   - **Signing Secret**: Paste the signing secret from Step 3
   - **Event Synchronization**: Enable the events you want (Messages, Thread Replies, Reactions)
   - **Emoji Reaction Actions**: Configure which emojis trigger which actions (see examples below)
6. Click **"Add Channel"**

### Finding Your Channel ID

1. In Slack, right-click on the channel name
2. Select **"View channel details"**
3. At the bottom of the dialog, you'll see the Channel ID (e.g., C1234567890)

## Step 5: Configure Slack Webhook URL

1. After creating the integration in Fizzy, you'll see the **Webhook URL** on the integration details page
2. Copy this URL
3. Go back to your Slack app settings → **"Event Subscriptions"**
4. Paste the URL into **"Request URL"**
5. Slack will verify the URL (you should see a green checkmark)
6. Click **"Save Changes"**

## Step 6: Install the App to Your Workspace

1. In your Slack app settings, go to **"Install App"**
2. Click **"Install to Workspace"**
3. Review the permissions and click **"Allow"**

## Step 7: Add the Bot to Your Channel

1. In Slack, go to the channel you want to integrate
2. Type `/invite @YourAppName` (replace with your app's name)
3. The bot should now appear in the channel

## Step 8: Configure Emoji Action Mappings

In Fizzy, edit your Slack integration and configure emoji mappings:

### Example Configurations

**Basic Workflow:**
- ✅ `white_check_mark` → Move to: Done
- 👀 `eyes` → Move to: In Progress
- ❌ `x` → Postpone (move to Not Now)

**Advanced Workflow:**
- 🚀 `rocket` → Move to: Ready for Launch
- 🔥 `fire` → Move to: High Priority
- 🎉 `tada` → Close card
- ⏳ `hourglass_flowing_sand` → Move to: Waiting

## Testing the Integration

### Test 1: Message Sync

1. Post a message in your Slack channel: "Test card creation"
2. Check your Fizzy board - a new card should appear
3. **Verify in Docker logs**: Look for `Slack webhook processed successfully`

### Test 2: Emoji Reaction Action

1. React to the Slack message with an emoji you've mapped (e.g., ✅)
2. Check Fizzy - the card should have moved to the configured column
3. **Verify in Docker logs**: Look for `Executing emoji action` and `Emoji action executed successfully`

### Test 3: Thread Reply Sync (if enabled)

1. Reply to the Slack message in a thread
2. Check Fizzy - a comment should appear on the card
3. **Verify in Docker logs**: Look for `Syncing thread reply`

## Troubleshooting

### Webhook Not Receiving Events

**Check Docker Logs:**
```bash
docker logs -f <container-name> | grep "Slack Webhook"
```

**Look for these log entries:**
- `=== Slack Webhook Received ===` - Webhook request received
- `Integration ID: <id>` - Integration being processed
- `Responding to URL verification challenge` - Initial Slack verification
- `Signature verification failed` - Secret mismatch (check your signing secret)
- `Integration not found` - Invalid integration ID in webhook URL

**Common Issues:**

1. **No webhook events received**
   - Verify the bot is in the channel (`/invite @YourAppName`)
   - Check Event Subscriptions are enabled in Slack app settings
   - Verify the Request URL is saved and shows a green checkmark
   - Check your Fizzy instance is publicly accessible

2. **Signature verification failed**
   - Error: `Signature verification failed for integration <id>`
   - Solution: Double-check the Signing Secret in Fizzy matches the one in Slack app settings
   - Copy the secret again from Slack → Basic Information → App Credentials

3. **Emoji action not triggering**
   - Log: `No action mapping found for emoji: <emoji_name>`
   - Solution: Verify the emoji name matches exactly (e.g., `white_check_mark` not `check_mark`)
   - Check emoji mappings in Fizzy integration settings

4. **500 Internal Server Error**
   - Check Docker logs for detailed stack trace
   - Look for `Error executing emoji action` with error details
   - Common causes:
     - Column not found (deleted column in mapping)
     - Card already in target state
     - Permission issues

### Diagnostic Logs

The system logs detailed information for troubleshooting:

**Webhook Receipt:**
```
=== Slack Webhook Received ===
Integration ID: <id>
Content-Type: application/json
Event type: reaction_added
```

**Emoji Action Processing:**
```
Processing reaction for card <card_id>
Emoji: white_check_mark
Action mapping found: {"action"=>"move_to_column", "column_id"=>"<id>"}
Executing emoji action: move_to_column
Moving card to column: Done
Emoji action executed successfully
```

**Errors:**
```
Error executing emoji action: <error message>
Full error: <stack trace>
```

### Testing Webhook Delivery

You can test if webhooks are being delivered:

1. Post a message in Slack
2. Immediately check Docker logs:
   ```bash
   docker logs -f <container-name> --tail=100
   ```
3. You should see the webhook event within seconds

If you don't see any logs, the webhook isn't reaching Fizzy (check your Slack app configuration).

## Slack API References

- [Event Subscriptions](https://api.slack.com/apis/connections/events-api)
- [Reaction Added Event](https://api.slack.com/events/reaction_added)
- [Request Signing](https://api.slack.com/authentication/verifying-requests-from-slack)
- [Message Event](https://api.slack.com/events/message.channels)

## Advanced Configuration

### Multiple Channels

You can set up multiple Slack channels with different emoji mappings per channel. Each integration can have its own custom workflow.

### Event Filtering

- Enable/disable message sync per channel
- Enable/disable thread replies per channel
- Enable/disable reactions per channel

### Account-Level Settings

Go to Account → Settings → Slack Settings to globally disable event types across all integrations.

## Security Notes

1. **Signing Secret**: Never commit your signing secret to version control
2. **Webhook URL**: The webhook URL contains the integration ID which is non-sensitive
3. **Request Verification**: All webhooks are verified using Slack's signature verification
4. **Timestamp Validation**: Requests older than 5 minutes are rejected to prevent replay attacks

## How It Works

### Architecture Flow

```
┌─────────────┐
│    Slack    │
│   Message   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Fizzy    │
│    Card     │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  React to   │
│   Message   │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  Slack Webhook      │
│  (reaction_added)   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Fizzy Processes    │
│  Emoji Mapping      │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Action Executed    │
│  (move/close/etc)   │
└─────────────────────┘
```

### Data Flow

1. Slack message is posted → Event webhook to Fizzy
2. Fizzy creates card and `SlackItem` record (links Slack message to Fizzy card)
3. User reacts with emoji → Reaction webhook to Fizzy
4. Fizzy finds the card via `SlackItem.slack_message_ts`
5. Fizzy checks emoji mapping configuration
6. If mapping exists → Execute action (move, close, postpone, etc.)
7. If no mapping → Add comment about reaction (default behavior)
8. Event is tracked in Fizzy with `via: "slack_reaction"` for audit trail

## Support

For issues or questions:
1. Check Docker logs first for detailed error messages
2. Verify Slack app configuration matches this guide
3. Test with a simple emoji mapping first (e.g., just one emoji)
4. Check the integration is active in Fizzy
