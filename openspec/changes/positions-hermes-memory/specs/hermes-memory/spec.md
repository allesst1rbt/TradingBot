# hermes-memory

## ADDED Requirements

### Requirement: Per-trade memory absorption
The system SHALL append every executed trade (facts plus the signal rationale) to the Hermes memory file at `HERMES_MEMORY_PATH` (default `/data/hermes_memory.md`), atomically (temp + rename), creating the file if missing.

#### Scenario: Trade appended with rationale
- **WHEN** a BUY trade executes with a signal rationale "uptrend"
- **THEN** the memory file contains a line with the trade facts and a rationale line, and no `.tmp` file remains

#### Scenario: File created when missing
- **WHEN** the memory file does not exist
- **THEN** the append creates it with the trade entry

### Requirement: Non-fatal failure
The system SHALL continue trading when a memory write fails, and SHALL record the failure in the run record.

#### Scenario: Memory write fails
- **WHEN** the memory path is not writable and a trade executes
- **THEN** the run completes, the trade persists, and the run record notes the memory failure
