# Pipeline buffering plan

This fork is an isolated agentic workflow experiment and is intentionally **not** meant for upstream merge.

## Goal

Track the datapath and control signals explicitly across stage boundaries so the current staged multi-cycle core can evolve toward a conventional 5-stage pipeline.

## First-pass changes in this fork

- Added explicit packed structs for stage boundary buffers:
  - `if_id_buf_t`
  - `id_ex_buf_t`
  - `ex_mem_buf_t`
  - `mem_wb_buf_t`
- Reworked `src/TOP/top.sv` so inter-stage data is routed through those named buffers.
- Preserved the current stage modules as much as possible so behavior stays close to the original design while visibility improves.

## Why this helps

The original design already had some local output buffering inside stage modules, but top-level signal flow still crossed stage boundaries as loose wires. That makes future hazard handling, flushing, bypassing, and pipeline validation harder to reason about.

These explicit structs make it easier to:

- identify exactly what each stage produces and consumes
- add per-stage valid/flush/stall semantics later
- inspect waveform groupings by stage boundary
- introduce forwarding / hazard detection with less ad-hoc wiring

## Likely next steps

1. Separate branch/jump redirect timing from MEM/WB-facing instruction fetch return data.
2. Move writeback control/data fully onto `mem_wb_q` semantics and audit register-file timing.
3. Add a hazard/flush unit for control-flow changes.
4. Add a waveform/debug view that dumps the pipeline structs cleanly in simulation.
5. Audit stage-local output buffering versus top-level pipeline-buffer ownership.

## Second-pass changes in this fork

- Added `valid` bits to all stage boundary buffer structs.
- Propagated buffer validity through `top.sv` so each stage boundary now has an explicit occupancy bit.
- Gated downstream control use with those validity bits to reduce accidental consumption of stale control signals.

## Third-pass changes in this fork

- Added a simple redirect-driven flush path in `top.sv`.
- When MEM resolves a taken branch/jump (`PCSrc` while `ex_mem_q.valid`), younger buffered stages are invalidated.
- This is intentionally minimal, but it gives the design an explicit bubble/flush concept instead of relying only on enable timing.

## Fourth-pass changes in this fork

- Separated fetch-return instruction ownership from MEM/WB state in `top.sv`.
- Added a dedicated `fetch_instr_q` path so IF consumes fetched instruction data without depending on writeback-stage buffering.
- This reduces one of the major structural mismatches between current staged execution and future pipelined ownership.

## Notes

This is a first structural pass, not a finished pipelined CPU. The current aim is signal ownership and buffering clarity.
