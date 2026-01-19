/**
 * DuckDB query integration for log analysis
 * Executes SQL queries using DuckDB CLI against JSONL log files
 */

import { getConfig } from "./config";
import { spawn } from "child_process";
import { existsSync } from "fs";

// Path to DuckDB CLI - check common locations
function findDuckDB(): string | null {
  const locations = [
    "/opt/homebrew/bin/duckdb",  // Homebrew Apple Silicon
    "/usr/local/bin/duckdb",     // Homebrew Intel / manual
    "/usr/bin/duckdb",           // System
  ];

  for (const loc of locations) {
    if (existsSync(loc)) {
      return loc;
    }
  }
  return null;
}

const duckdbPath = findDuckDB();

/**
 * Initialize DuckDB - just verify CLI exists
 */
export function initDuckDB(): void {
  if (duckdbPath) {
    console.log(`DuckDB CLI found at: ${duckdbPath}`);
  } else {
    console.log("DuckDB CLI not found - query feature disabled");
    console.log("Install with: brew install duckdb");
  }
}

/**
 * Execute a query against the log files using DuckDB CLI
 */
export async function executeQuery(sql: string): Promise<QueryResult> {
  if (!duckdbPath) {
    return {
      success: false,
      error: "DuckDB CLI not found. Install with: brew install duckdb",
      duration: 0,
      columns: [],
      rows: []
    };
  }

  const config = getConfig();
  const logsDir = config.logsDir;

  // Replace relative file references with absolute paths
  const processedSql = sql.replace(
    /read_json_auto\s*\(\s*['"]([^'"]+)['"]\s*\)/gi,
    (match, filename) => {
      if (filename.startsWith("/")) {
        return match;
      }
      const fullPath = `${logsDir}/${filename}`;
      return `read_json_auto('${fullPath}')`;
    }
  );

  return new Promise((resolve) => {
    const startTime = Date.now();
    let stdout = "";
    let stderr = "";

    // Run DuckDB CLI with JSON output
    const proc = spawn(duckdbPath, ["-json", "-c", processedSql], {
      cwd: logsDir,
      timeout: 30000
    });

    proc.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    proc.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    proc.on("close", (code) => {
      const duration = Date.now() - startTime;

      if (code !== 0 || stderr) {
        resolve({
          success: false,
          error: stderr || `DuckDB exited with code ${code}`,
          duration,
          columns: [],
          rows: []
        });
        return;
      }

      try {
        // DuckDB JSON output is an array of objects
        const results = JSON.parse(stdout || "[]");

        if (!Array.isArray(results) || results.length === 0) {
          resolve({
            success: true,
            duration,
            columns: [],
            rows: [],
            rowCount: 0
          });
          return;
        }

        // Extract columns from first row
        const columns = Object.keys(results[0]);

        // Convert to row arrays
        const rows = results.map(row => {
          return columns.map(col => {
            const val = row[col];
            if (typeof val === "object" && val !== null) {
              return JSON.stringify(val);
            }
            return val;
          });
        });

        resolve({
          success: true,
          duration,
          columns,
          rows,
          rowCount: rows.length
        });

      } catch (e) {
        resolve({
          success: false,
          error: `Failed to parse DuckDB output: ${e}`,
          duration,
          columns: [],
          rows: []
        });
      }
    });

    proc.on("error", (err) => {
      const duration = Date.now() - startTime;
      resolve({
        success: false,
        error: `Failed to run DuckDB: ${err.message}`,
        duration,
        columns: [],
        rows: []
      });
    });
  });
}

/**
 * Get list of available log files for query hints
 */
export function getAvailableFiles(): string[] {
  const config = getConfig();
  const { readdirSync, statSync } = require("fs");
  const { join } = require("path");

  try {
    const files = readdirSync(config.logsDir);
    return files.filter((f: string) => {
      const fullPath = join(config.logsDir, f);
      return statSync(fullPath).isFile() && f.endsWith(".jsonl");
    });
  } catch {
    return [];
  }
}

/**
 * Close DuckDB - no-op for CLI approach
 */
export function closeDuckDB(): void {
  // Nothing to close with CLI approach
}

export interface QueryResult {
  success: boolean;
  error?: string;
  duration: number;
  columns: string[];
  rows: any[][];
  rowCount?: number;
}
