/**
 * Main HTTP server entry point
 * Handles log ingestion, metrics, and UI serving
 */

import { serve } from "bun";
import { join, dirname } from "path";
import { existsSync, readFileSync } from "fs";
import { initConfig, getConfig, getChannelConfig, setChannelConfig } from "./config";
import { enqueue, flushAll, shutdown, getQueueStats, getTotalQueueDepth } from "./queue";
import { getChannels, getChannelFileInfo, type LogEntry } from "./writer";
import { getAllMetrics, getChannelMetrics } from "./metrics";
import { initDuckDB, executeQuery, getAvailableFiles, closeDuckDB } from "./query";

// Resolve project root from script location
// When running: bun run /path/to/Project/logserver/server.ts
// scriptDir = .../Project/logserver
// Project root (4D database root) is two levels up, containing Project/ and Data/ folders
const scriptDir = dirname(Bun.main);
const projectRoot = join(scriptDir, "..", "..");

// Initialize configuration
const config = initConfig(projectRoot);

// Initialize DuckDB
initDuckDB();

console.log(`Log server starting...`);
console.log(`  Project root: ${projectRoot}`);
console.log(`  Logs directory: ${config.logsDir}`);
console.log(`  Port: ${config.port}`);

/**
 * Parse and validate a log entry from request body
 */
function parseLogEntry(body: unknown): LogEntry | null {
  if (!body || typeof body !== "object") return null;
  
  const obj = body as Record<string, unknown>;
  
  // Required fields
  if (typeof obj.channel !== "string" || !obj.channel) return null;
  if (typeof obj.message !== "string") return null;
  
  // Level with default
  const validLevels = ["debug", "info", "warn", "error"];
  const level = validLevels.includes(obj.level as string) 
    ? (obj.level as LogEntry["level"]) 
    : "info";
  
  // Timestamp - use provided or generate
  const timestamp = typeof obj.timestamp === "string" 
    ? obj.timestamp 
    : new Date().toISOString();
  
  return {
    channel: obj.channel,
    level,
    message: obj.message,
    timestamp,
    data: typeof obj.data === "object" ? (obj.data as Record<string, unknown>) : undefined
  };
}

/**
 * Serve static files from ui/ directory
 */
function serveStatic(path: string): Response {
  const uiDir = join(scriptDir, "ui");
  const filePath = path === "/" || path === "" ? "index.html" : path.slice(1);
  const fullPath = join(uiDir, filePath);
  
  if (!existsSync(fullPath)) {
    return new Response("Not found", { status: 404 });
  }
  
  const content = readFileSync(fullPath);
  const ext = filePath.split(".").pop() || "";
  const contentTypes: Record<string, string> = {
    html: "text/html",
    css: "text/css",
    js: "application/javascript",
    json: "application/json"
  };
  
  return new Response(content, {
    headers: { "Content-Type": contentTypes[ext] || "application/octet-stream" }
  });
}

/**
 * CORS headers for all responses
 */
function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  };
}

/**
 * JSON response helper
 */
function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders()
    }
  });
}

// Start HTTP server
const server = serve({
  port: config.port,
  
  async fetch(req) {
    const url = new URL(req.url);
    const path = url.pathname;
    
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }
    
    // --- API Routes ---
    
    // POST /log - Main log ingestion endpoint
    if (path === "/log" && req.method === "POST") {
      try {
        const body = await req.json();
        const entry = parseLogEntry(body);
        
        if (!entry) {
          return jsonResponse({ error: "Invalid log entry" }, 400);
        }
        
        enqueue(entry);
        return jsonResponse({ ok: true });
        
      } catch (e) {
        return jsonResponse({ error: "Invalid JSON" }, 400);
      }
    }
    
    // POST /log/batch - Batch log ingestion
    if (path === "/log/batch" && req.method === "POST") {
      try {
        const body = await req.json();
        
        if (!Array.isArray(body)) {
          return jsonResponse({ error: "Expected array of log entries" }, 400);
        }
        
        let accepted = 0;
        let rejected = 0;
        
        for (const item of body) {
          const entry = parseLogEntry(item);
          if (entry) {
            enqueue(entry);
            accepted++;
          } else {
            rejected++;
          }
        }
        
        return jsonResponse({ ok: true, accepted, rejected });
        
      } catch (e) {
        return jsonResponse({ error: "Invalid JSON" }, 400);
      }
    }
    
    // GET /channels - List available channels
    if (path === "/channels" && req.method === "GET") {
      const channels = getChannels();
      const channelInfo = channels.map(channel => ({
        name: channel,
        config: getChannelConfig(channel),
        ...getChannelFileInfo(channel),
        metrics: getChannelMetrics(channel)
      }));
      
      return jsonResponse(channelInfo);
    }
    
    // GET /channel/:name - Get channel details
    if (path.startsWith("/channel/") && req.method === "GET") {
      const channel = path.slice("/channel/".length);
      
      return jsonResponse({
        name: channel,
        config: getChannelConfig(channel),
        ...getChannelFileInfo(channel),
        metrics: getChannelMetrics(channel)
      });
    }
    
    // POST /channel/:name/config - Update channel config
    if (path.startsWith("/channel/") && path.endsWith("/config") && req.method === "POST") {
      const channel = path.slice("/channel/".length, -"/config".length);
      
      try {
        const body = await req.json();
        setChannelConfig(channel, body);
        return jsonResponse({ ok: true, config: getChannelConfig(channel) });
      } catch (e) {
        return jsonResponse({ error: "Invalid JSON" }, 400);
      }
    }
    
    // GET /metrics - Server metrics
    if (path === "/metrics" && req.method === "GET") {
      return jsonResponse({
        queueDepth: getTotalQueueDepth(),
        queueStats: getQueueStats(),
        channels: getAllMetrics()
      });
    }
    
    // POST /flush - Force flush all queues
    if (path === "/flush" && req.method === "POST") {
      flushAll();
      return jsonResponse({ ok: true, message: "All queues flushed" });
    }
    
    // GET /health - Health check
    if (path === "/health" && req.method === "GET") {
      return jsonResponse({
        status: "ok",
        uptime: process.uptime(),
        queueDepth: getTotalQueueDepth()
      });
    }

    // POST /query - Execute DuckDB query
    if (path === "/query" && req.method === "POST") {
      try {
        const body = await req.json();
        const sql = body.sql;

        if (typeof sql !== "string" || !sql.trim()) {
          return jsonResponse({ error: "Missing or empty 'sql' field" }, 400);
        }

        const result = await executeQuery(sql);
        return jsonResponse(result);

      } catch (e) {
        return jsonResponse({ error: "Invalid JSON" }, 400);
      }
    }

    // GET /query/files - List available log files for queries
    if (path === "/query/files" && req.method === "GET") {
      return jsonResponse({
        files: getAvailableFiles(),
        logsDir: config.logsDir
      });
    }

    // --- UI Routes ---
    
    // Serve UI from /ui/ path or root
    if (path.startsWith("/ui") || path === "/") {
      const staticPath = path === "/" ? "/" : path.slice("/ui".length) || "/";
      return serveStatic(staticPath);
    }
    
    return new Response("Not found", { status: 404, headers: corsHeaders() });
  }
});

console.log(`Log server running at http://localhost:${config.port}`);
console.log(`  UI available at: http://localhost:${config.port}/`);
console.log(`  Log endpoint: POST http://localhost:${config.port}/log`);

// Graceful shutdown handling
process.on("SIGTERM", async () => {
  console.log("Received SIGTERM, shutting down gracefully...");
  await shutdown();
  closeDuckDB();
  server.stop();
  process.exit(0);
});

process.on("SIGINT", async () => {
  console.log("Received SIGINT, shutting down gracefully...");
  await shutdown();
  closeDuckDB();
  server.stop();
  process.exit(0);
});
