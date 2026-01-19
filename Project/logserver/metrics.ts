/**
 * Metrics tracking for volume and velocity per channel
 * Used to adapt queue flushing strategy
 */

interface ChannelMetrics {
  entriesTotal: number;
  entriesLastMinute: number;
  entriesLastSecond: number;
  lastEntryTime: number;
  bytesWritten: number;
  flushCount: number;
  avgFlushLatency: number;
  timestamps: number[];  // rolling window for velocity calc
}

interface FlushStrategy {
  intervalMs: number;
  batchSize: number;
}

const metrics: Map<string, ChannelMetrics> = new Map();
const VELOCITY_WINDOW_MS = 1000;  // 1 second window for velocity

function getOrCreateMetrics(channel: string): ChannelMetrics {
  if (!metrics.has(channel)) {
    metrics.set(channel, {
      entriesTotal: 0,
      entriesLastMinute: 0,
      entriesLastSecond: 0,
      lastEntryTime: 0,
      bytesWritten: 0,
      flushCount: 0,
      avgFlushLatency: 0,
      timestamps: []
    });
  }
  return metrics.get(channel)!;
}

/**
 * Record an incoming log entry
 */
export function recordEntry(channel: string): void {
  const m = getOrCreateMetrics(channel);
  const now = Date.now();
  
  m.entriesTotal++;
  m.lastEntryTime = now;
  m.timestamps.push(now);
  
  // Prune old timestamps (keep last second)
  const cutoff = now - VELOCITY_WINDOW_MS;
  m.timestamps = m.timestamps.filter(t => t > cutoff);
  m.entriesLastSecond = m.timestamps.length;
}

/**
 * Record a flush operation
 */
export function recordFlush(channel: string, entryCount: number, bytes: number, latencyMs: number): void {
  const m = getOrCreateMetrics(channel);
  m.bytesWritten += bytes;
  m.flushCount++;
  
  // Rolling average for flush latency
  m.avgFlushLatency = m.avgFlushLatency === 0 
    ? latencyMs 
    : (m.avgFlushLatency * 0.9 + latencyMs * 0.1);
}

/**
 * Get current velocity (entries per second) for a channel
 */
export function getVelocity(channel: string): number {
  const m = metrics.get(channel);
  if (!m) return 0;
  
  const now = Date.now();
  const cutoff = now - VELOCITY_WINDOW_MS;
  m.timestamps = m.timestamps.filter(t => t > cutoff);
  return m.timestamps.length;
}

/**
 * Determine flush strategy based on current velocity
 */
export function getFlushStrategy(channel: string): FlushStrategy {
  const velocity = getVelocity(channel);
  
  if (velocity < 10) {
    // Low velocity: flush quickly, small batches
    return { intervalMs: 100, batchSize: 10 };
  } else if (velocity < 100) {
    // Medium velocity: balance latency and throughput
    return { intervalMs: 500, batchSize: 50 };
  } else {
    // High velocity: prioritize throughput
    return { intervalMs: 1000, batchSize: 500 };
  }
}

/**
 * Get metrics snapshot for all channels
 */
export function getAllMetrics(): Record<string, ChannelMetrics & { velocity: number }> {
  const result: Record<string, ChannelMetrics & { velocity: number }> = {};
  
  for (const [channel, m] of metrics) {
    result[channel] = {
      ...m,
      velocity: getVelocity(channel)
    };
  }
  
  return result;
}

/**
 * Get metrics for a specific channel
 */
export function getChannelMetrics(channel: string): (ChannelMetrics & { velocity: number }) | null {
  const m = metrics.get(channel);
  if (!m) return null;
  
  return {
    ...m,
    velocity: getVelocity(channel)
  };
}

/**
 * Reset metrics (useful for testing)
 */
export function resetMetrics(): void {
  metrics.clear();
}
