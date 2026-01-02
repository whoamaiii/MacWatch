# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clarity (MacWatch) is a macOS usage analytics application that tracks app usage, input activity, and focus sessions. It consists of three components:

- **ClarityApp**: SwiftUI GUI with menu bar integration (macOS 14+)
- **ClarityDaemon**: Background service that collects usage data
- **ClarityShared**: Shared library with models and SQLite database layer

## Build Commands

```bash
# Build all targets
swift build

# Build specific product
swift build --product ClarityApp
swift build --product ClarityDaemon

# Release build
swift build -c release

# Run tests
swift test

# Run specific test
swift test --filter ClarityTests.testAppCategoryFromBundleId

# Clean build artifacts
swift package clean
```

## Running the Application

```bash
# Run the GUI app
.build/debug/ClarityApp

# Run the daemon (background data collection)
.build/debug/ClarityDaemon
```

The daemon requires Accessibility permission to monitor input events and window focus. The app's PermissionManager handles permission requests.

## Architecture

### Data Flow
```
ClarityDaemon (collectors) → minute_stats → Aggregator → daily_stats
                                    ↓
                           ClarityApp (queries & displays)
```

### Key Components

**ClarityDaemon** (`Sources/ClarityDaemon/`):
- `WindowCollector`: Tracks app focus changes via NSWorkspace notifications, polls window titles
- `InputCollector`: Captures keystrokes/clicks/scrolls via CGEvent tap, stores keycode frequency for heatmap
- `SystemCollector`: Monitors screen sleep, battery, power source changes
- `Aggregator`: Rolls up minute stats to daily stats at midnight

**ClarityShared** (`Sources/ClarityShared/`):
- `DatabaseManager`: Singleton GRDB SQLite manager at `~/Library/Application Support/Clarity/clarity.db`
- `StatsRepository`: CRUD for minute_stats, daily_stats, focus_sessions, keycode frequency
- `AppRepository`: App metadata management with auto-categorization from bundle IDs
- Models: `App`, `MinuteStat`, `DailyStat`, `FocusSession`, `RawEvent`

**ClarityApp** (`Sources/ClarityApp/`):
- `DaemonManager`: Starts/stops daemon, monitors health every 5s, auto-restarts on crash
- `PermissionManager`: Handles Accessibility permission flow
- `DataService`: Central data access layer for all views
- Views: Dashboard, Timeline, Apps, Input (with KeyboardHeatmap), Focus, Insights, System, Settings

### Views & Features

| View | Features |
|------|----------|
| Dashboard | Today's stats, focus score, top apps |
| Timeline | Hourly activity breakdown by app |
| Apps | App usage ranking with categories |
| Input | Keyboard heatmap, keystroke/click stats, hourly charts |
| Focus | Focus session tracking, deep work detection |
| Insights | Productivity patterns and tips |
| System | Battery, session info, database stats |
| Settings | Tracking toggles, data retention, export (JSON/CSV), launch at login |

### Database Schema

| Table | Purpose | Retention |
|-------|---------|-----------|
| apps | App metadata | Permanent |
| minute_stats | Per-minute aggregates (indexed on timestamp + appId) | 90 days (configurable) |
| daily_stats | Daily summaries | Permanent |
| focus_sessions | Deep work periods (>=25min, <3 interruptions) | Permanent |
| raw_events | Ephemeral event log, keycode frequency | 7 days |

### Dependencies

- **GRDB.swift** (v6.29.3): SQLite wrapper with migrations and WAL mode

## macOS Integration

Requires **Accessibility permission** for:
- Window title retrieval (AXUIElement API)
- Input event tapping (CGEvent)
- App focus tracking

Uses NSWorkspace notifications, IOKit for battery, DistributedNotificationCenter for system events.

## Project Status

Core functionality is complete (~95%):

### Implemented Features
- ✅ Window/app tracking with automatic categorization
- ✅ Input monitoring with keyboard heatmap and click tracking
- ✅ Focus session tracking with deep work detection
- ✅ Full UI with all views (Dashboard, Timeline, Apps, Input, Focus, Insights, System, Settings, Achievements)
- ✅ Settings with data export (JSON/CSV), tracking toggles, data retention
- ✅ CPU/memory per-process tracking (via SystemCollector)
- ✅ Browser tab title extraction (Safari, Chrome, Brave, Edge, Arc, Opera, Vivaldi)
- ✅ Achievement/gamification system with 14 achievements across 4 categories
- ✅ Claude Desktop Extension (MCP server) for natural language usage queries

### Distribution Setup
For app signing and notarization, see the `Makefile` targets:
- `make release` - Build release binaries
- `make sign` - Sign with Developer ID (requires DEVELOPER_ID env var)
- `make notarize` - Notarize with Apple (requires APPLE_ID and APP_PASSWORD env vars)
- `make dmg` - Create distributable DMG

### Requirements for Distribution
1. Apple Developer account ($99/year)
2. Developer ID Application certificate
3. App-specific password for notarization
