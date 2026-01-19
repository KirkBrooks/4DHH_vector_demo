/**
 * In-memory queue with adaptive flushing
 * Buffers incoming log entries and flushes based on velocity
 */

import { writeBatch, type LogEntry } from "./writer";
import { recordEntry, getFlushStrategy } from "./metrics";

interface ChannelQueue {
  entries: LogEntry[];
  timer: ReturnType<typeof setTimeout> | null;
  lastFlush: number;
}

const queues: Map<string, ChannelQueue> = new Map();
let shutdownRequested = false;

function getOrCreateQueue(channel: string): ChannelQueue {
  if (!queues.has(channel)) {
    queues.set(channel, {
      entries: [],
      timer: null,
      lastFlush: Date.now()
    });
  }
  return queues.get(channel)!;
}

/**
 * Schedule a flush for a channel based on current velocity
 */
function scheduleFlush(channel: string): void {
  const queue = getOrCreateQueue(channel);
  
  // Clear existing timer
  if (queue.timer) {
    clearTimeout(queue.timer);
    queue.timer = null;
  }
  
  if (shutdownRequested) {
    // During shutdown, flush immediately
    flushChannel(channel);
    return;
  }
  
  const strategy = getFlushStrategy(channel);
  
  // Flush if batch size reached
  if (queue.entries.length >= strategy.batchSize) {
    flushChannel(channel);
    return;
  }
  
  // Schedule timer-based flush
  queue.timer = setTimeout(() => {
    flushChannel(channel);
  }, strategy.intervalMs);
}

/**
 * Flush all entries for a channel to disk
 */
function flushChannel(channel: string): void {
  const queue = queues.get(channel);
  if (!queue || queue.entries.length === 0) return;
  
  // Clear timer
  if (queue.timer) {
    clearTimeout(queue.timer);
    queue.timer = null;
  }
  
  // Take all entries and clear the queue
  const entries = queue.entries;
  queue.entries = [];
  queue.lastFlush = Date.now();
  
  // Write to disk
  try {
    writeBatch(channel, entries);
  } catch (e) {
    console.error(`Error flushing channel ${channel}:`, e);
    // On error, put entries back (best effort)
    queue.entries = [...entries, ...queue.entries];
  }
}

/**
 * Enqueue a log entry
 */
export function enqueue(entry: LogEntry): void {
  if (shutdownRequested) {
    // During shutdown, write directly
    writeBatch(entry.channel, [entry]);
    return;
  }
  
  const queue = getOrCreateQueue(entry.channel);
  queue.entries.push(entry);
  
  // Record metrics
  recordEntry(entry.channel);
  
  // Schedule or trigger flush
  scheduleFlush(entry.channel);
}

/**
 * Flush all channels immediately
 */
export function flushAll(): void {
  for (const channel of queues.keys()) {
    flushChannel(channel);
  }
}

/**
 * Get current queue depth for a channel
 */
export function getQueueDepth(channel: string): number {
  const queue = queues.get(channel);
  return queue ? queue.entries.length : 0;
}

/**
 * Get total queue depth across all channels
 */
export function getTotalQueueDepth(): number {
  let total = 0;
  for (const queue of queues.values()) {
    total += queue.entries.length;
  }
  return total;
}

/**
 * Get queue stats for all channels
 */
export function getQueueStats(): Record<string, { depth: number; lastFlush: Date }> {
  const stats: Record<string, { depth: number; lastFlush: Date }> = {};
  
  for (const [channel, queue] of queues) {
    stats[channel] = {
      depth: queue.entries.length,
      lastFlush: new Date(queue.lastFlush)
    };
  }
  
  return stats;
}

/**
 * Initiate graceful shutdown
 * Flushes all queues and prevents new entries from being queued
 */
export function shutdown(): Promise<void> {
  return new Promise((resolve) => {
    console.log("Shutting down queue, flushing all channels...");
    shutdownRequested = true;
    
    // Clear all timers
    for (const queue of queues.values()) {
      if (queue.timer) {
        clearTimeout(queue.timer);
        queue.timer = null;
      }
    }
    
    // Flush everything
    flushAll();
    
    console.log("All channels flushed");
    resolve();
  });
}

/**
 * Check if shutdown has been requested
 */
export function isShuttingDown(): boolean {
  return shutdownRequested;
}
