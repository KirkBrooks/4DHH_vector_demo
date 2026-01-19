# Log Server Project Summary

## Overview

A fire-and-forget logging system for 4D that offloads logging to a local Bun HTTP server. The goal is to remove logging burden from the 4D database while providing robust log examination capabilities.

## Architecture

```
┌─────────┐     POST /log      ┌──────────────────────────────────────┐
│   4D    │ ─────────────────► │           Bun HTTP Server            │
└─────────┘   fire & forget    │                                      │
                               │  ┌─────────────┐    ┌─────────────┐  │
                               │  │ In-Memory   │───►│ Log Files   │  │
                               │  │ Queue       │    │ (rotation)  │  │
                               │  └─────────────┘    └─────────────┘  │
                               │                            │         │
                               │  ┌─────────────┐           │         │
                               │  │ Web UI      │◄──────────┘         │
                               │  │ (query/view)│    DuckDB           │
                               │  └─────────────┘                     │
                               └──────────────────────────────────────┘
```

## File Layout

```
4DProject/
├── Data/
│   └── Logs/                   # Output directory for log files
├── Project/
│   ├── Sources/
│   │   └── Methods/
│   │       ├── LOG_Entry.4dm           # Fire-and-forget log method
│   │       ├── LOG_Server_Start.4dm    # Start server (call from On Startup)
│   │       ├── LOG_Server_Stop.4dm     # Stop server (call from On Exit)
│   │       ├── LOG_Test.4dm            # Test harness
│   │       ├── LOG__Server_OnData.4dm  # Internal: stdout handler
│   │       ├── LOG__Server_OnError.4dm # Internal: stderr handler
│   │       ├── LOG__Server_OnTerminate.4dm # Internal: termination handler
│   │       ├── LOG__HTTP_Response.4dm  # Internal: async HTTP callback
│   │       └── LOG__HTTP_Error.4dm     # Internal: async HTTP error callback
│   └── logserver/
│       ├── bin/
│       │   └── bun                     # Bundled Bun binary (not checked in)
│       ├── ui/
│       │   └── index.html              # Web UI for log viewing
│       ├── queries/                    # Saved DuckDB query definitions
│       ├── server.ts                   # Main HTTP server
│       ├── queue.ts                    # Adaptive batching queue
│       ├── writer.ts                   # File writing with rotation
│       ├── config.ts                   # Configuration management
│       ├── metrics.ts                  # Volume/velocity tracking
│       └── config.json                 # User-editable config
```

## Key Design Decisions

### 1. Bun as HTTP Server
- Single binary, no dependencies
- Built-in HTTP server
- TypeScript out of the box
- Binary goes in `logserver/bin/` for portability

### 2. Adaptive Queue Flushing
Based on velocity (entries/second):
- Low (<10/sec): flush every 100ms, batch of 10
- Medium (10-100/sec): flush every 500ms, batch of 50
- High (>100/sec): flush every 1s, batch of 500

### 3. Log Format
JSONL by default:
```json
{"channel":"app","level":"info","message":"User login","timestamp":"2025-01-19T...","data":{"userId":123}}
```

### 4. Channel Auto-Configuration
New channels are auto-created with defaults. Users can override via config.json or API.

### 5. DuckDB for Queries
Direct file queries (no database to maintain). User enters raw DuckDB SQL.

## 4D Integration

### Startup (On Startup method)
```4d
$result:=LOG_Server_Start
If (Not($result.success))
    // Handle error - $result.message has details
End if
```

### Shutdown (On Exit method)
```4d
LOG_Server_Stop
```

### Logging
```4d
LOG_Entry("channel"; "level"; "message"; $dataObject)

// Examples:
LOG_Entry("app"; "info"; "User logged in"; New object("userId"; 123))
LOG_Entry("errors"; "error"; "Database connection failed")
LOG_Entry("debug"; "debug"; "Processing record"; New object("id"; $id))
```

### Key 4D Pattern: Escaping Folder Sandbox
```4d
// WRONG - sandboxed, can't access parent
$path:=Folder(fk database folder; *).parent.platformPath

// CORRECT - escape sandbox first
$path:=Folder(Folder(fk database folder; *).platformPath; fk platform path).parent.platformPath
```

## HTTP API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/log` | POST | Single log entry |
| `/log/batch` | POST | Multiple log entries |
| `/channels` | GET | List all channels with stats |
| `/channel/:name` | GET | Channel details |
| `/channel/:name/config` | POST | Update channel config |
| `/metrics` | GET | Server metrics |
| `/flush` | POST | Force flush all queues |
| `/health` | GET | Health check |
| `/` | GET | Web UI |

## Configuration (config.json)

```json
{
  "port": 3333,
  "defaults": {
    "maxFileSize": 10485760,
    "maxFiles": 5,
    "format": "jsonl"
  },
  "channels": {
    "verbose": {
      "maxFileSize": 5242880,
      "maxFiles": 10
    }
  }
}
```

## Installation

### 1. Install Bun binary in logserver/bin/

```bash
cd Project/logserver
mkdir -p bin
cd bin

# For Apple Silicon Mac:
curl -fsSL https://github.com/oven-sh/bun/releases/latest/download/bun-darwin-aarch64.zip -o bun.zip

# For Intel Mac:
# curl -fsSL https://github.com/oven-sh/bun/releases/latest/download/bun-darwin-x64.zip -o bun.zip

unzip bun.zip
mv bun-*/bun ./
rm -rf bun-* bun.zip
chmod +x bun
```

### 2. Test manually
```bash
cd Project/logserver
./bin/bun run server.ts
```

### 3. Test with curl
```bash
curl -X POST http://localhost:3333/log \
  -H "Content-Type: application/json" \
  -d '{"channel":"test","level":"info","message":"Hello"}'

curl http://localhost:3333/health
```

## Work Remaining

### Phase 2: Query & UI
- [ ] `query.ts` - DuckDB integration for direct file queries
- [ ] Complete `ui/index.html` - add query execution, results display
- [ ] Saved query management (load/save from queries/ folder)
- [ ] Export filtered results to file

### Phase 3: Polish
- [ ] Real-time log tailing in UI
- [ ] Column visibility toggles
- [ ] Query hints/autocomplete
- [ ] Error handling improvements

## Files to Create in logserver/

All TypeScript files need to be created. The 4D methods exist in Project/Sources/Methods/.

### server.ts (main entry point)
- HTTP routes for /log, /channels, /metrics, /health, etc.
- Serves static UI from ui/
- CORS headers
- Graceful shutdown on SIGTERM/SIGINT

### queue.ts
- In-memory queue per channel
- Adaptive flush timing based on velocity
- Graceful shutdown flushes all queues

### writer.ts
- File rotation based on size
- JSONL or text format
- Channel file discovery

### config.ts
- Load/save config.json
- Per-channel overrides
- Auto-create directories

### metrics.ts
- Track entries/second per channel
- Rolling window for velocity calculation
- Determine flush strategy

### ui/index.html
- Channel list with stats
- Query input (raw DuckDB SQL)
- Results table
- Auto-refresh toggle

## 4D Methods Created

| Method | Status | Notes |
|--------|--------|-------|
| LOG_Entry | ✅ Complete | Uses 4D.HTTPRequest for async |
| LOG_Server_Start | ✅ Complete | Looks for bun in logserver/bin/ first |
| LOG_Server_Stop | ✅ Complete | SIGTERM with timeout |
| LOG_Test | ✅ Complete | Sends test entries |
| LOG__Server_OnData | ✅ Complete | stdout handler |
| LOG__Server_OnError | ✅ Complete | stderr handler |
| LOG__Server_OnTerminate | ✅ Complete | cleanup handler |
| LOG__HTTP_Response | ✅ Complete | empty callback |
| LOG__HTTP_Error | ✅ Complete | empty callback |
