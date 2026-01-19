/**
 * File writing and rotation logic
 * Handles log file creation, appending, and rotation based on size
 */

import { existsSync, statSync, renameSync, unlinkSync, appendFileSync, readdirSync } from "fs";
import { join } from "path";
import { getConfig, getChannelConfig, type ChannelConfig } from "./config";
import { recordFlush } from "./metrics";

export interface LogEntry {
  channel: string;
  level: "debug" | "info" | "warn" | "error";
  message: string;
  timestamp: string;
  data?: Record<string, unknown>;
}

/**
 * Get the current log file path for a channel
 */
function getLogFilePath(channel: string, config: ChannelConfig): string {
  const { logsDir } = getConfig();
  const ext = config.format === "jsonl" ? "jsonl" : "log";
  return join(logsDir, `${channel}.${ext}`);
}

/**
 * Check if rotation is needed and perform it
 */
function rotateIfNeeded(channel: string, config: ChannelConfig): void {
  const filePath = getLogFilePath(channel, config);
  
  if (!existsSync(filePath)) return;
  
  const stats = statSync(filePath);
  if (stats.size < config.maxFileSize) return;
  
  // Rotate files: channel.log -> channel.1.log -> channel.2.log -> ...
  const { logsDir } = getConfig();
  const ext = config.format === "jsonl" ? "jsonl" : "log";
  
  // Delete oldest if at max
  const oldestPath = join(logsDir, `${channel}.${config.maxFiles}.${ext}`);
  if (existsSync(oldestPath)) {
    unlinkSync(oldestPath);
  }
  
  // Shift existing rotated files
  for (let i = config.maxFiles - 1; i >= 1; i--) {
    const fromPath = join(logsDir, `${channel}.${i}.${ext}`);
    const toPath = join(logsDir, `${channel}.${i + 1}.${ext}`);
    if (existsSync(fromPath)) {
      renameSync(fromPath, toPath);
    }
  }
  
  // Rotate current file to .1
  const firstRotated = join(logsDir, `${channel}.1.${ext}`);
  renameSync(filePath, firstRotated);
  
  console.log(`Rotated log file for channel: ${channel}`);
}

/**
 * Format an entry for text output
 */
function formatText(entry: LogEntry): string {
  const dataStr = entry.data ? ` | ${JSON.stringify(entry.data)}` : "";
  return `${entry.timestamp} [${entry.level.toUpperCase()}] ${entry.message}${dataStr}\n`;
}

/**
 * Format an entry for JSONL output
 */
function formatJsonl(entry: LogEntry): string {
  return JSON.stringify(entry) + "\n";
}

/**
 * Write a batch of entries to disk
 * Returns the number of bytes written
 */
export function writeBatch(channel: string, entries: LogEntry[]): number {
  if (entries.length === 0) return 0;
  
  const startTime = Date.now();
  const config = getChannelConfig(channel);
  
  // Check rotation before writing
  rotateIfNeeded(channel, config);
  
  const filePath = getLogFilePath(channel, config);
  const formatter = config.format === "jsonl" ? formatJsonl : formatText;
  
  // Build the content to write
  const content = entries.map(formatter).join("");
  const bytes = Buffer.byteLength(content, "utf-8");
  
  // Append to file
  appendFileSync(filePath, content, "utf-8");
  
  const latency = Date.now() - startTime;
  recordFlush(channel, entries.length, bytes, latency);
  
  return bytes;
}

/**
 * Get list of all log files for a channel (including rotated)
 */
export function getLogFiles(channel: string): string[] {
  const { logsDir } = getConfig();
  const config = getChannelConfig(channel);
  const ext = config.format === "jsonl" ? "jsonl" : "log";
  
  const files: string[] = [];
  const currentPath = join(logsDir, `${channel}.${ext}`);
  
  if (existsSync(currentPath)) {
    files.push(currentPath);
  }
  
  // Check for rotated files
  for (let i = 1; i <= config.maxFiles; i++) {
    const rotatedPath = join(logsDir, `${channel}.${i}.${ext}`);
    if (existsSync(rotatedPath)) {
      files.push(rotatedPath);
    }
  }
  
  return files;
}

/**
 * Get list of all channels (based on existing log files)
 */
export function getChannels(): string[] {
  const { logsDir } = getConfig();
  
  if (!existsSync(logsDir)) return [];
  
  const files = readdirSync(logsDir);
  const channels = new Set<string>();
  
  for (const file of files) {
    // Match: channel.jsonl, channel.log, channel.1.jsonl, etc.
    const match = file.match(/^([^.]+)(?:\.\d+)?\.(?:jsonl|log)$/);
    if (match) {
      channels.add(match[1]);
    }
  }
  
  return Array.from(channels).sort();
}

/**
 * Get file info for a channel
 */
export function getChannelFileInfo(channel: string): { 
  files: Array<{ path: string; size: number; modified: Date }>;
  totalSize: number;
} {
  const files = getLogFiles(channel);
  const fileInfo = files.map(path => {
    const stats = statSync(path);
    return {
      path,
      size: stats.size,
      modified: stats.mtime
    };
  });
  
  const totalSize = fileInfo.reduce((sum, f) => sum + f.size, 0);
  
  return { files: fileInfo, totalSize };
}
