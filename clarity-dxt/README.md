# Clarity Usage Analytics - Desktop Extension

A Claude Desktop Extension (DXT) that provides access to your macOS usage analytics collected by the Clarity app.

## Features

Query your usage data through Claude:

- **Today's Summary** - Get a quick overview of today's activity
- **Daily Statistics** - View detailed stats for any date or date range
- **Top Apps** - See which apps you use most
- **Hourly Breakdown** - Understand your activity patterns throughout the day
- **Focus Sessions** - Track your deep work sessions
- **App Usage** - Get detailed statistics for specific apps
- **Weekly Summary** - Review your week at a glance
- **Productivity Trends** - Analyze patterns over time

## Prerequisites

1. **Clarity App** - The Clarity macOS app must be installed and have collected some usage data
2. **Node.js 18+** - Required runtime for the MCP server
3. **Claude Desktop** - Version 0.10.0 or later

## Installation

### Option 1: Install from .dxt file (Recommended)

1. Build the extension:
   ```bash
   cd clarity-dxt
   npm install
   npx @anthropic-ai/mcpb pack
   ```

2. Double-click the generated `.dxt` file to install in Claude Desktop

### Option 2: Manual Installation

1. Install dependencies:
   ```bash
   cd clarity-dxt
   npm install
   ```

2. Add to Claude Desktop's MCP configuration (`~/Library/Application Support/Claude/claude_desktop_config.json`):
   ```json
   {
     "mcpServers": {
       "clarity-usage-analytics": {
         "command": "node",
         "args": ["/path/to/clarity-dxt/server/index.js"]
       }
     }
   }
   ```

3. Restart Claude Desktop

## Usage Examples

Once installed, you can ask Claude things like:

- "What's my usage summary for today?"
- "Which apps did I use most yesterday?"
- "Show me my hourly activity breakdown for today"
- "How much time did I spend in VS Code this week?"
- "What are my productivity trends for the past month?"
- "Show me my focus sessions from today"
- "Give me a weekly summary of my computer usage"

## Available Tools

| Tool | Description |
|------|-------------|
| `get_today_summary` | Get today's usage summary |
| `get_daily_stats` | Get stats for a specific date or range |
| `get_top_apps` | Get most-used apps for a date |
| `get_hourly_breakdown` | Get hourly activity breakdown |
| `get_focus_sessions` | Get focus/deep work sessions |
| `get_app_usage` | Get detailed stats for a specific app |
| `get_weekly_summary` | Get past week's summary |
| `get_productivity_trends` | Analyze productivity patterns |

## Data Location

The extension reads from the Clarity database at:
```
~/Library/Application Support/Clarity/clarity.db
```

The database is accessed in read-only mode - no data is modified.

## Troubleshooting

### "Database not found" error
Ensure the Clarity app has been run at least once to create the database.

### No data returned
Make sure the Clarity daemon is running and collecting data. Check the Clarity app's status.

### Permission issues
The extension needs read access to the Clarity database file.

## Development

### Building
```bash
npm install
npm run build  # if using TypeScript
```

### Testing locally
```bash
node server/index.js
```

### Packaging
```bash
npx @anthropic-ai/mcpb pack
```

## License

MIT
