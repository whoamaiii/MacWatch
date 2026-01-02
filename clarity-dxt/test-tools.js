#!/usr/bin/env node

/**
 * Test script for Clarity MCP tools
 * Run with: node test-tools.js
 */

import Database from "better-sqlite3";
import { homedir } from "os";
import { join } from "path";
import { existsSync } from "fs";

const DB_PATH = join(
  homedir(),
  "Library",
  "Application Support",
  "Clarity",
  "clarity.db"
);

console.log("=== Clarity DXT Tool Tests ===\n");

// Check database exists
if (!existsSync(DB_PATH)) {
  console.error(`Database not found at: ${DB_PATH}`);
  console.error("Please run the Clarity app first to create the database.");
  process.exit(1);
}

const db = new Database(DB_PATH, { readonly: true });

// Test 1: Database tables
console.log("1. Checking database tables...");
const tables = db
  .prepare(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
  )
  .all();
console.log("   Tables found:", tables.map((t) => t.name).join(", "));

// Test 2: Apps count
console.log("\n2. Checking apps table...");
const appCount = db.prepare("SELECT COUNT(*) as count FROM apps").get();
console.log(`   Apps tracked: ${appCount.count}`);

if (appCount.count > 0) {
  const sampleApps = db
    .prepare("SELECT name, category FROM apps LIMIT 5")
    .all();
  console.log(
    "   Sample apps:",
    sampleApps.map((a) => `${a.name} (${a.category})`).join(", ")
  );
}

// Test 3: Minute stats
console.log("\n3. Checking minute_stats table...");
const statCount = db
  .prepare("SELECT COUNT(*) as count FROM minute_stats")
  .get();
console.log(`   Minute stats records: ${statCount.count}`);

if (statCount.count > 0) {
  const todayStart = Math.floor(
    new Date().setHours(0, 0, 0, 0) / 1000
  );
  const todayStats = db
    .prepare(
      `
    SELECT
      SUM(activeSeconds) as active,
      SUM(keystrokes) as keys,
      SUM(clicks) as clicks
    FROM minute_stats
    WHERE timestamp >= ?
  `
    )
    .get(todayStart);
  console.log(
    `   Today: ${todayStats.active || 0}s active, ${todayStats.keys || 0} keystrokes, ${todayStats.clicks || 0} clicks`
  );
}

// Test 4: Daily stats
console.log("\n4. Checking daily_stats table...");
const dailyCount = db
  .prepare("SELECT COUNT(*) as count FROM daily_stats")
  .get();
console.log(`   Daily stats records: ${dailyCount.count}`);

if (dailyCount.count > 0) {
  const latestDaily = db
    .prepare(
      "SELECT date, totalActiveSeconds, totalKeystrokes FROM daily_stats ORDER BY date DESC LIMIT 1"
    )
    .get();
  console.log(
    `   Latest: ${latestDaily.date} - ${Math.floor(latestDaily.totalActiveSeconds / 60)}min active, ${latestDaily.totalKeystrokes} keystrokes`
  );
}

// Test 5: Focus sessions
console.log("\n5. Checking focus_sessions table...");
const focusCount = db
  .prepare("SELECT COUNT(*) as count FROM focus_sessions")
  .get();
console.log(`   Focus session records: ${focusCount.count}`);

// Test 6: Top apps query
console.log("\n6. Testing top apps query...");
const todayStart = Math.floor(new Date().setHours(0, 0, 0, 0) / 1000);
const topApps = db
  .prepare(
    `
  SELECT a.name, SUM(m.activeSeconds) as seconds
  FROM minute_stats m
  JOIN apps a ON m.appId = a.id
  WHERE m.timestamp >= ?
  GROUP BY a.id
  ORDER BY seconds DESC
  LIMIT 5
`
  )
  .all(todayStart);

if (topApps.length > 0) {
  console.log("   Today's top apps:");
  topApps.forEach((app, i) => {
    const mins = Math.floor(app.seconds / 60);
    console.log(`   ${i + 1}. ${app.name}: ${mins}min`);
  });
} else {
  console.log("   No app usage data for today yet");
}

console.log("\n=== All tests passed ===");
console.log("\nThe MCP server should work correctly with this database.");

db.close();
