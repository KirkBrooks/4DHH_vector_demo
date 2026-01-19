/**
 * Configuration management for the log server
 * Handles defaults, per-channel overrides, and runtime config
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync } from "fs";
import { join, dirname } from "path";

export interface ChannelConfig {
  maxFileSize: number;      // bytes, default 10MB
  maxFiles: number;         // number of rotated files to keep
  format: "text" | "jsonl"; // output format
}

export interface ServerConfig {
  port: number;
  logsDir: string;
  queriesDir: string;
  defaults: ChannelConfig;
  channels: Record<string, Partial<ChannelConfig>>;
}

const DEFAULT_CONFIG: ServerConfig = {
  port: 3333,
  logsDir: "",        // Set at runtime based on project structure
  queriesDir: "",     // Set at runtime
  defaults: {
    maxFileSize: 10 * 1024 * 1024,  // 10MB
    maxFiles: 5,
    format: "jsonl"
  },
  channels: {}
};

let config: ServerConfig = { ...DEFAULT_CONFIG };
let configPath: string = "";

/**
 * Initialize configuration
 * @param projectRoot - Path to the 4D project root (parent of Project folder)
 */
export function initConfig(projectRoot: string): ServerConfig {
  // Derive paths from project structure
  const logsDir = join(projectRoot, "Data", "Logs");
  const serverDir = join(projectRoot, "logserver");
  const queriesDir = join(serverDir, "queries");
  configPath = join(serverDir, "config.json");

  // Ensure directories exist
  if (!existsSync(logsDir)) {
    mkdirSync(logsDir, { recursive: true });
    console.log(`Created logs directory: ${logsDir}`);
  }
  if (!existsSync(queriesDir)) {
    mkdirSync(queriesDir, { recursive: true });
    console.log(`Created queries directory: ${queriesDir}`);
  }

  // Load or create config file
  if (existsSync(configPath)) {
    try {
      const fileConfig = JSON.parse(readFileSync(configPath, "utf-8"));
      config = {
        ...DEFAULT_CONFIG,
        ...fileConfig,
        logsDir,
        queriesDir,
        defaults: { ...DEFAULT_CONFIG.defaults, ...fileConfig.defaults },
        channels: fileConfig.channels || {}
      };
      console.log(`Loaded config from: ${configPath}`);
    } catch (e) {
      console.error(`Error loading config, using defaults: ${e}`);
      config = { ...DEFAULT_CONFIG, logsDir, queriesDir };
    }
  } else {
    config = { ...DEFAULT_CONFIG, logsDir, queriesDir };
    saveConfig();
    console.log(`Created default config: ${configPath}`);
  }

  return config;
}

/**
 * Save current config to disk
 */
export function saveConfig(): void {
  if (!configPath) return;
  
  // Don't save computed paths - they're derived at runtime
  const toSave = {
    port: config.port,
    defaults: config.defaults,
    channels: config.channels
  };
  
  writeFileSync(configPath, JSON.stringify(toSave, null, 2));
}

/**
 * Get config for a specific channel, merging with defaults
 */
export function getChannelConfig(channel: string): ChannelConfig {
  const channelOverrides = config.channels[channel] || {};
  return {
    ...config.defaults,
    ...channelOverrides
  };
}

/**
 * Update channel-specific config
 */
export function setChannelConfig(channel: string, overrides: Partial<ChannelConfig>): void {
  config.channels[channel] = {
    ...config.channels[channel],
    ...overrides
  };
  saveConfig();
}

/**
 * Get the full server config
 */
export function getConfig(): ServerConfig {
  return config;
}

/**
 * Update server port (requires restart to take effect)
 */
export function setPort(port: number): void {
  config.port = port;
  saveConfig();
}
