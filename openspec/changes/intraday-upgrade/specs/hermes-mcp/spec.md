# hermes-mcp

## ADDED Requirements

### Requirement: Supervised Hermes MCP child on localhost
The system SHALL run Hermes as a supervised child process serving MCP bound to `127.0.0.1` only, and MUST NOT expose any port on a public interface.

#### Scenario: Server is localhost-only
- **WHEN** the Hermes MCP child starts
- **THEN** it listens on 127.0.0.1 (loopback) and the container has no public port mapping

#### Scenario: Child restarts after crash
- **WHEN** the Hermes MCP child exits unexpectedly
- **THEN** the supervisor restarts it (at most once per run) and the next run proceeds

### Requirement: MCP client per-symbol analysis
The system SHALL implement an MCP client (initialize → tools/list → tools/call) and SHALL invoke the analysis tool once per symbol per run.

#### Scenario: Tool call returns analysis
- **WHEN** the client calls the analysis tool with a compact prompt for symbol BTC
- **THEN** the tool result text is returned and parsed as a signal JSON (same schema as before)

#### Scenario: MCP failure degrades run
- **WHEN** the MCP child is unreachable or the tool call errors
- **THEN** the run completes with the affected symbols marked as skipped, a `runs` row is still written, and a Telegram alert is sent

### Requirement: No shell-out fallback
The system MUST NOT spawn `hermes -z` processes; the MCP path is the only Hermes integration.

#### Scenario: Shell-out removed
- **WHEN** a standard run executes
- **THEN** no `System.cmd`-based Hermes invocation occurs (BotTrader.Hermes module is gone from the pipeline)
