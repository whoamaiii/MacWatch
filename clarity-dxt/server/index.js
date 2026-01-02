#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import Database from "better-sqlite3";
import { homedir } from "os";
import { join } from "path";
import { existsSync } from "fs";

// Database path
const DB_PATH = join(
  homedir(),
  "Library",
  "Application Support",
  "Clarity",
  "clarity.db"
);

// Logging utility
function log(message, level = "info") {
  const timestamp = new Date().toISOString();
  console.error(`[${timestamp}] [${level.toUpperCase()}] ${message}`);
}

// Database connection wrapper
class ClarityDatabase {
  constructor() {
    this.db = null;
  }

  connect() {
    if (!existsSync(DB_PATH)) {
      throw new Error(
        `Clarity database not found at ${DB_PATH}. Please ensure the Clarity app has been run at least once.`
      );
    }

    try {
      this.db = new Database(DB_PATH, { readonly: true });
      log(`Connected to Clarity database at ${DB_PATH}`);
    } catch (error) {
      throw new Error(`Failed to connect to database: ${error.message}`);
    }
  }

  close() {
    if (this.db) {
      this.db.close();
      this.db = null;
    }
  }

  query(sql, params = []) {
    if (!this.db) {
      this.connect();
    }
    return this.db.prepare(sql).all(...params);
  }

  get(sql, params = []) {
    if (!this.db) {
      this.connect();
    }
    return this.db.prepare(sql).get(...params);
  }
}

// Helper functions
function formatDuration(seconds) {
  if (!seconds || seconds === 0) return "0m";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
}

function formatDate(date) {
  return date.toISOString().split("T")[0];
}

function getStartOfDay(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

function getEndOfDay(date) {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return Math.floor(d.getTime() / 1000);
}

function parseDate(dateStr) {
  if (!dateStr) return new Date();
  const parsed = new Date(dateStr);
  if (isNaN(parsed.getTime())) {
    throw new Error(`Invalid date format: ${dateStr}. Use YYYY-MM-DD format.`);
  }
  return parsed;
}

// Initialize database
const db = new ClarityDatabase();

// Tool implementations
const tools = {
  get_today_summary: {
    description:
      "Get today's usage summary including active time, keystrokes, clicks, and focus time",
    inputSchema: {
      type: "object",
      properties: {},
      required: [],
    },
    handler: async () => {
      const today = new Date();
      const startTimestamp = getStartOfDay(today);

      // Get minute stats aggregates
      const stats = db.get(
        `
        SELECT
          COALESCE(SUM(activeSeconds), 0) as totalActiveSeconds,
          COALESCE(SUM(keystrokes), 0) as totalKeystrokes,
          COALESCE(SUM(clicks), 0) as totalClicks,
          COALESCE(SUM(scrollDistance), 0) as totalScroll,
          COUNT(DISTINCT appId) as uniqueApps
        FROM minute_stats
        WHERE timestamp >= ?
      `,
        [startTimestamp]
      );

      // Get focus sessions
      const focusStats = db.get(
        `
        SELECT
          COUNT(*) as sessionCount,
          COALESCE(SUM(
            CASE WHEN endTime IS NOT NULL
            THEN CAST((julianday(endTime) - julianday(startTime)) * 86400 AS INTEGER)
            ELSE 0 END
          ), 0) as totalFocusSeconds
        FROM focus_sessions
        WHERE date(startTime) = date('now', 'localtime')
      `
      );

      // Get top 3 apps
      const topApps = db.query(
        `
        SELECT a.name, SUM(m.activeSeconds) as seconds
        FROM minute_stats m
        JOIN apps a ON m.appId = a.id
        WHERE m.timestamp >= ?
        GROUP BY a.id
        ORDER BY seconds DESC
        LIMIT 3
      `,
        [startTimestamp]
      );

      return {
        date: formatDate(today),
        activeTime: formatDuration(stats?.totalActiveSeconds || 0),
        activeSeconds: stats?.totalActiveSeconds || 0,
        keystrokes: stats?.totalKeystrokes || 0,
        clicks: stats?.totalClicks || 0,
        scrollDistance: stats?.totalScroll || 0,
        uniqueApps: stats?.uniqueApps || 0,
        focusSessions: focusStats?.sessionCount || 0,
        focusTime: formatDuration(focusStats?.totalFocusSeconds || 0),
        focusSeconds: focusStats?.totalFocusSeconds || 0,
        topApps: topApps.map((app) => ({
          name: app.name,
          time: formatDuration(app.seconds),
        })),
      };
    },
  },

  get_daily_stats: {
    description:
      "Get daily usage statistics for a specific date or date range",
    inputSchema: {
      type: "object",
      properties: {
        date: {
          type: "string",
          description: "Date in YYYY-MM-DD format (defaults to today)",
        },
        startDate: {
          type: "string",
          description: "Start date for range query (YYYY-MM-DD)",
        },
        endDate: {
          type: "string",
          description: "End date for range query (YYYY-MM-DD)",
        },
      },
      required: [],
    },
    handler: async (args) => {
      if (args.startDate && args.endDate) {
        // Range query
        const stats = db.query(
          `
          SELECT * FROM daily_stats
          WHERE date >= ? AND date <= ?
          ORDER BY date DESC
        `,
          [args.startDate, args.endDate]
        );

        return stats.map((s) => ({
          date: s.date,
          activeTime: formatDuration(s.totalActiveSeconds),
          focusTime: formatDuration(s.totalFocusSeconds),
          keystrokes: s.totalKeystrokes,
          clicks: s.totalClicks,
          focusScore: Math.round(s.focusScore * 10) / 10,
          productivityScore: Math.round(s.productivityScore * 10) / 10,
        }));
      }

      // Single date query
      const date = args.date || formatDate(new Date());
      const stat = db.get(`SELECT * FROM daily_stats WHERE date = ?`, [date]);

      if (!stat) {
        // Fall back to minute_stats aggregation
        const startTimestamp = getStartOfDay(parseDate(date));
        const endTimestamp = getEndOfDay(parseDate(date));

        const agg = db.get(
          `
          SELECT
            COALESCE(SUM(activeSeconds), 0) as totalActiveSeconds,
            COALESCE(SUM(keystrokes), 0) as totalKeystrokes,
            COALESCE(SUM(clicks), 0) as totalClicks
          FROM minute_stats
          WHERE timestamp >= ? AND timestamp <= ?
        `,
          [startTimestamp, endTimestamp]
        );

        return {
          date: date,
          activeTime: formatDuration(agg?.totalActiveSeconds || 0),
          activeSeconds: agg?.totalActiveSeconds || 0,
          keystrokes: agg?.totalKeystrokes || 0,
          clicks: agg?.totalClicks || 0,
          note: "Data from minute_stats (daily aggregation not yet available)",
        };
      }

      return {
        date: stat.date,
        activeTime: formatDuration(stat.totalActiveSeconds),
        activeSeconds: stat.totalActiveSeconds,
        focusTime: formatDuration(stat.totalFocusSeconds),
        focusSeconds: stat.totalFocusSeconds,
        keystrokes: stat.totalKeystrokes,
        clicks: stat.totalClicks,
        scrollDistance: stat.totalScroll,
        focusScore: Math.round(stat.focusScore * 10) / 10,
        productivityScore: Math.round(stat.productivityScore * 10) / 10,
        firstActivity: stat.firstActivity,
        lastActivity: stat.lastActivity,
      };
    },
  },

  get_top_apps: {
    description:
      "Get the most-used apps for a specific date, ranked by active time",
    inputSchema: {
      type: "object",
      properties: {
        date: {
          type: "string",
          description: "Date in YYYY-MM-DD format (defaults to today)",
        },
        limit: {
          type: "number",
          description: "Maximum number of apps to return (default: 10)",
        },
      },
      required: [],
    },
    handler: async (args) => {
      const date = parseDate(args.date);
      const limit = args.limit || 10;
      const startTimestamp = getStartOfDay(date);
      const endTimestamp = getEndOfDay(date);

      const apps = db.query(
        `
        SELECT
          a.name,
          a.bundleId,
          a.category,
          SUM(m.activeSeconds) as totalSeconds,
          SUM(m.keystrokes) as keystrokes,
          SUM(m.clicks) as clicks
        FROM minute_stats m
        JOIN apps a ON m.appId = a.id
        WHERE m.timestamp >= ? AND m.timestamp <= ?
        GROUP BY a.id
        ORDER BY totalSeconds DESC
        LIMIT ?
      `,
        [startTimestamp, endTimestamp, limit]
      );

      const totalSeconds = apps.reduce((sum, a) => sum + a.totalSeconds, 0);

      return {
        date: formatDate(date),
        totalActiveTime: formatDuration(totalSeconds),
        apps: apps.map((app) => ({
          name: app.name,
          bundleId: app.bundleId,
          category: app.category,
          time: formatDuration(app.totalSeconds),
          seconds: app.totalSeconds,
          percentage:
            totalSeconds > 0
              ? Math.round((app.totalSeconds / totalSeconds) * 100)
              : 0,
          keystrokes: app.keystrokes,
          clicks: app.clicks,
        })),
      };
    },
  },

  get_hourly_breakdown: {
    description: "Get an hourly breakdown of activity for a specific date",
    inputSchema: {
      type: "object",
      properties: {
        date: {
          type: "string",
          description: "Date in YYYY-MM-DD format (defaults to today)",
        },
      },
      required: [],
    },
    handler: async (args) => {
      const date = parseDate(args.date);
      const startTimestamp = getStartOfDay(date);

      const hourlyData = db.query(
        `
        SELECT
          ((timestamp - ?) / 3600) as hour,
          SUM(activeSeconds) as seconds,
          SUM(keystrokes) as keystrokes,
          SUM(clicks) as clicks
        FROM minute_stats
        WHERE timestamp >= ? AND timestamp < ? + 86400
        GROUP BY hour
        ORDER BY hour
      `,
        [startTimestamp, startTimestamp, startTimestamp]
      );

      // Build complete 24-hour breakdown
      const breakdown = [];
      for (let h = 0; h < 24; h++) {
        const data = hourlyData.find((d) => d.hour === h);
        breakdown.push({
          hour: h,
          timeLabel: `${h.toString().padStart(2, "0")}:00`,
          activeTime: formatDuration(data?.seconds || 0),
          seconds: data?.seconds || 0,
          keystrokes: data?.keystrokes || 0,
          clicks: data?.clicks || 0,
        });
      }

      // Find peak hours
      const activeHours = breakdown.filter((h) => h.seconds > 0);
      const peakHour = activeHours.reduce(
        (max, h) => (h.seconds > max.seconds ? h : max),
        { seconds: 0 }
      );

      return {
        date: formatDate(date),
        breakdown: breakdown,
        summary: {
          activeHours: activeHours.length,
          peakHour: peakHour.timeLabel || "N/A",
          peakHourTime: formatDuration(peakHour.seconds),
        },
      };
    },
  },

  get_focus_sessions: {
    description: "Get focus/deep work sessions for a specific date",
    inputSchema: {
      type: "object",
      properties: {
        date: {
          type: "string",
          description: "Date in YYYY-MM-DD format (defaults to today)",
        },
      },
      required: [],
    },
    handler: async (args) => {
      const date = args.date || formatDate(new Date());

      const sessions = db.query(
        `
        SELECT
          fs.id,
          fs.startTime,
          fs.endTime,
          fs.keystrokes,
          fs.clicks,
          fs.interruptions,
          a.name as primaryApp
        FROM focus_sessions fs
        LEFT JOIN apps a ON fs.primaryAppId = a.id
        WHERE date(fs.startTime) = ?
        ORDER BY fs.startTime DESC
      `,
        [date]
      );

      const formattedSessions = sessions.map((s) => {
        let durationSeconds = 0;
        if (s.endTime) {
          const start = new Date(s.startTime);
          const end = new Date(s.endTime);
          durationSeconds = Math.floor((end - start) / 1000);
        }

        const isDeepWork = durationSeconds >= 25 * 60 && s.interruptions < 3;

        return {
          id: s.id,
          startTime: s.startTime,
          endTime: s.endTime || "In progress",
          duration: formatDuration(durationSeconds),
          durationSeconds: durationSeconds,
          keystrokes: s.keystrokes,
          clicks: s.clicks,
          interruptions: s.interruptions,
          primaryApp: s.primaryApp || "Unknown",
          isDeepWork: isDeepWork,
        };
      });

      const totalFocusSeconds = formattedSessions.reduce(
        (sum, s) => sum + s.durationSeconds,
        0
      );
      const deepWorkSessions = formattedSessions.filter((s) => s.isDeepWork);

      return {
        date: date,
        sessions: formattedSessions,
        summary: {
          totalSessions: sessions.length,
          deepWorkSessions: deepWorkSessions.length,
          totalFocusTime: formatDuration(totalFocusSeconds),
          averageSessionLength:
            sessions.length > 0
              ? formatDuration(Math.floor(totalFocusSeconds / sessions.length))
              : "0m",
        },
      };
    },
  },

  get_app_usage: {
    description: "Get detailed usage statistics for a specific app",
    inputSchema: {
      type: "object",
      properties: {
        appName: {
          type: "string",
          description: "Name of the app (partial match supported)",
        },
        bundleId: {
          type: "string",
          description: "Bundle ID of the app (exact match)",
        },
        days: {
          type: "number",
          description: "Number of days to look back (default: 7)",
        },
      },
      required: [],
    },
    handler: async (args) => {
      const days = args.days || 7;
      const startTimestamp = getStartOfDay(
        new Date(Date.now() - days * 24 * 60 * 60 * 1000)
      );

      // Find the app
      let app;
      if (args.bundleId) {
        app = db.get(`SELECT * FROM apps WHERE bundleId = ?`, [args.bundleId]);
      } else if (args.appName) {
        app = db.get(`SELECT * FROM apps WHERE name LIKE ?`, [
          `%${args.appName}%`,
        ]);
      } else {
        throw new Error(
          "Either appName or bundleId must be provided"
        );
      }

      if (!app) {
        throw new Error(`App not found: ${args.appName || args.bundleId}`);
      }

      // Get usage stats
      const stats = db.get(
        `
        SELECT
          COALESCE(SUM(activeSeconds), 0) as totalSeconds,
          COALESCE(SUM(keystrokes), 0) as totalKeystrokes,
          COALESCE(SUM(clicks), 0) as totalClicks,
          COUNT(DISTINCT date(timestamp, 'unixepoch', 'localtime')) as daysUsed
        FROM minute_stats
        WHERE appId = ? AND timestamp >= ?
      `,
        [app.id, startTimestamp]
      );

      // Get daily breakdown
      const dailyBreakdown = db.query(
        `
        SELECT
          date(timestamp, 'unixepoch', 'localtime') as date,
          SUM(activeSeconds) as seconds,
          SUM(keystrokes) as keystrokes
        FROM minute_stats
        WHERE appId = ? AND timestamp >= ?
        GROUP BY date
        ORDER BY date DESC
      `,
        [app.id, startTimestamp]
      );

      return {
        app: {
          name: app.name,
          bundleId: app.bundleId,
          category: app.category,
          isDistraction: app.isDistraction ? true : false,
          firstSeen: app.firstSeen,
        },
        period: {
          days: days,
          startDate: formatDate(
            new Date(Date.now() - days * 24 * 60 * 60 * 1000)
          ),
          endDate: formatDate(new Date()),
        },
        stats: {
          totalTime: formatDuration(stats?.totalSeconds || 0),
          totalSeconds: stats?.totalSeconds || 0,
          averageDaily: formatDuration(
            Math.floor((stats?.totalSeconds || 0) / days)
          ),
          keystrokes: stats?.totalKeystrokes || 0,
          clicks: stats?.totalClicks || 0,
          daysUsed: stats?.daysUsed || 0,
        },
        dailyBreakdown: dailyBreakdown.map((d) => ({
          date: d.date,
          time: formatDuration(d.seconds),
          keystrokes: d.keystrokes,
        })),
      };
    },
  },

  get_weekly_summary: {
    description: "Get a summary of usage statistics for the past week",
    inputSchema: {
      type: "object",
      properties: {},
      required: [],
    },
    handler: async () => {
      const endDate = new Date();
      const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const startTimestamp = getStartOfDay(startDate);

      // Get aggregated stats
      const stats = db.get(
        `
        SELECT
          COALESCE(SUM(activeSeconds), 0) as totalActiveSeconds,
          COALESCE(SUM(keystrokes), 0) as totalKeystrokes,
          COALESCE(SUM(clicks), 0) as totalClicks,
          COUNT(DISTINCT date(timestamp, 'unixepoch', 'localtime')) as activeDays
        FROM minute_stats
        WHERE timestamp >= ?
      `,
        [startTimestamp]
      );

      // Get daily breakdown
      const dailyStats = db.query(
        `
        SELECT
          date(timestamp, 'unixepoch', 'localtime') as date,
          SUM(activeSeconds) as seconds
        FROM minute_stats
        WHERE timestamp >= ?
        GROUP BY date
        ORDER BY date
      `,
        [startTimestamp]
      );

      // Get top apps for the week
      const topApps = db.query(
        `
        SELECT
          a.name,
          a.category,
          SUM(m.activeSeconds) as totalSeconds
        FROM minute_stats m
        JOIN apps a ON m.appId = a.id
        WHERE m.timestamp >= ?
        GROUP BY a.id
        ORDER BY totalSeconds DESC
        LIMIT 5
      `,
        [startTimestamp]
      );

      // Get focus session stats
      const focusStats = db.get(
        `
        SELECT
          COUNT(*) as sessionCount,
          COALESCE(SUM(
            CASE WHEN endTime IS NOT NULL
            THEN CAST((julianday(endTime) - julianday(startTime)) * 86400 AS INTEGER)
            ELSE 0 END
          ), 0) as totalFocusSeconds
        FROM focus_sessions
        WHERE startTime >= datetime(?, 'unixepoch', 'localtime')
      `,
        [startTimestamp]
      );

      const avgDailySeconds =
        stats?.activeDays > 0
          ? Math.floor(stats.totalActiveSeconds / stats.activeDays)
          : 0;

      return {
        period: {
          startDate: formatDate(startDate),
          endDate: formatDate(endDate),
          activeDays: stats?.activeDays || 0,
        },
        totals: {
          activeTime: formatDuration(stats?.totalActiveSeconds || 0),
          activeSeconds: stats?.totalActiveSeconds || 0,
          keystrokes: stats?.totalKeystrokes || 0,
          clicks: stats?.totalClicks || 0,
          focusSessions: focusStats?.sessionCount || 0,
          focusTime: formatDuration(focusStats?.totalFocusSeconds || 0),
        },
        averages: {
          dailyActiveTime: formatDuration(avgDailySeconds),
          dailyKeystrokes: Math.floor(
            (stats?.totalKeystrokes || 0) / (stats?.activeDays || 1)
          ),
        },
        dailyBreakdown: dailyStats.map((d) => ({
          date: d.date,
          time: formatDuration(d.seconds),
          seconds: d.seconds,
        })),
        topApps: topApps.map((app) => ({
          name: app.name,
          category: app.category,
          time: formatDuration(app.totalSeconds),
        })),
      };
    },
  },

  get_productivity_trends: {
    description: "Analyze productivity trends over a specified period",
    inputSchema: {
      type: "object",
      properties: {
        days: {
          type: "number",
          description: "Number of days to analyze (default: 30)",
        },
      },
      required: [],
    },
    handler: async (args) => {
      const days = args.days || 30;
      const startTimestamp = getStartOfDay(
        new Date(Date.now() - days * 24 * 60 * 60 * 1000)
      );

      // Get daily stats
      const dailyStats = db.query(
        `
        SELECT
          date(timestamp, 'unixepoch', 'localtime') as date,
          SUM(activeSeconds) as activeSeconds,
          SUM(keystrokes) as keystrokes
        FROM minute_stats
        WHERE timestamp >= ?
        GROUP BY date
        ORDER BY date
      `,
        [startTimestamp]
      );

      // Get category breakdown
      const categoryStats = db.query(
        `
        SELECT
          a.category,
          SUM(m.activeSeconds) as totalSeconds
        FROM minute_stats m
        JOIN apps a ON m.appId = a.id
        WHERE m.timestamp >= ?
        GROUP BY a.category
        ORDER BY totalSeconds DESC
      `,
        [startTimestamp]
      );

      // Calculate trends
      const totalDays = dailyStats.length;
      if (totalDays < 2) {
        return {
          period: { days, dataPoints: totalDays },
          message: "Not enough data to calculate trends",
        };
      }

      const firstHalf = dailyStats.slice(0, Math.floor(totalDays / 2));
      const secondHalf = dailyStats.slice(Math.floor(totalDays / 2));

      const firstHalfAvg =
        firstHalf.reduce((sum, d) => sum + d.activeSeconds, 0) /
        firstHalf.length;
      const secondHalfAvg =
        secondHalf.reduce((sum, d) => sum + d.activeSeconds, 0) /
        secondHalf.length;

      const trend =
        secondHalfAvg > firstHalfAvg
          ? "increasing"
          : secondHalfAvg < firstHalfAvg
            ? "decreasing"
            : "stable";
      const changePercent = Math.round(
        ((secondHalfAvg - firstHalfAvg) / firstHalfAvg) * 100
      );

      // Find most and least productive days
      const sortedDays = [...dailyStats].sort(
        (a, b) => b.activeSeconds - a.activeSeconds
      );
      const mostProductive = sortedDays[0];
      const leastProductive = sortedDays[sortedDays.length - 1];

      // Calculate day-of-week patterns
      const dowStats = {};
      for (const day of dailyStats) {
        const dow = new Date(day.date).toLocaleDateString("en-US", {
          weekday: "long",
        });
        if (!dowStats[dow]) {
          dowStats[dow] = { total: 0, count: 0 };
        }
        dowStats[dow].total += day.activeSeconds;
        dowStats[dow].count++;
      }

      const dowAverages = Object.entries(dowStats)
        .map(([day, stats]) => ({
          day,
          average: formatDuration(Math.floor(stats.total / stats.count)),
          averageSeconds: Math.floor(stats.total / stats.count),
        }))
        .sort((a, b) => b.averageSeconds - a.averageSeconds);

      return {
        period: {
          days: days,
          actualDataPoints: totalDays,
          startDate: dailyStats[0]?.date,
          endDate: dailyStats[dailyStats.length - 1]?.date,
        },
        trend: {
          direction: trend,
          changePercent: changePercent,
          firstHalfAverage: formatDuration(Math.floor(firstHalfAvg)),
          secondHalfAverage: formatDuration(Math.floor(secondHalfAvg)),
        },
        highlights: {
          mostProductiveDay: mostProductive
            ? {
                date: mostProductive.date,
                time: formatDuration(mostProductive.activeSeconds),
              }
            : null,
          leastProductiveDay: leastProductive
            ? {
                date: leastProductive.date,
                time: formatDuration(leastProductive.activeSeconds),
              }
            : null,
        },
        dayOfWeekPatterns: dowAverages,
        categoryBreakdown: categoryStats.map((c) => ({
          category: c.category,
          time: formatDuration(c.totalSeconds),
          seconds: c.totalSeconds,
        })),
      };
    },
  },
};

// Create MCP server
const server = new Server(
  {
    name: "clarity-usage-analytics",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Register tool list handler
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: Object.entries(tools).map(([name, tool]) => ({
      name,
      description: tool.description,
      inputSchema: tool.inputSchema,
    })),
  };
});

// Register tool call handler
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  const tool = tools[name];
  if (!tool) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ error: `Unknown tool: ${name}` }),
        },
      ],
      isError: true,
    };
  }

  try {
    const result = await tool.handler(args || {});
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  } catch (error) {
    log(`Error executing tool ${name}: ${error.message}`, "error");
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            error: error.message,
            tool: name,
          }),
        },
      ],
      isError: true,
    };
  }
});

// Start server
async function main() {
  try {
    // Test database connection
    db.connect();
    log("Database connection verified");
  } catch (error) {
    log(`Warning: ${error.message}`, "warn");
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);
  log("Clarity Usage Analytics MCP server running on stdio");
}

main().catch((error) => {
  log(`Fatal error: ${error.message}`, "error");
  process.exit(1);
});
