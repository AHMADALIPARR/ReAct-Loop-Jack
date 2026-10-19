# MobiusBridge

I forge mathematical invariants directly into an executable text segment.

MobiusBridge models a hijacked ReAct loop — a state machine where
processing a module decrements the workload, but a prompt injection
artificially refreshes the synthetic token budget to bypass the
timeout. The Cycle-Stealing Invariant says: if there is still work in
the queue, the orchestrator's execution budget must remain > 0.

I prove that invariant twice, in two systems:

- **Lean 4** (`lean/MobiusBridge.lean`) — the theorem
  `cycle_preservation`, checked by the Lean kernel.
- **Liquid Haskell** (`MobiusBridge.hs`) — the same invariant as a
  refinement type, `executeBatch :: GoodState -> GoodState`, checked
  by Z3 at compile time.

Then I wire Liquid Haskell into GHC as a compiler plugin, so
**compilation itself is the synchronization barrier**. If the SMT
solver cannot prove the `GoodState` implication at the boundary, GHC
physically halts the build and refuses to emit the object file. If
the binary exists, the invariant is absolute.

## The pipeline

1. **Haskell worker** (`mobius-worker`, `Main.hs`) — the impure IO
   shell. Connects to `127.0.0.1:8080`, streams
   `ROUND:<n>|PENDING:<n>|BUDGET:<n>` lines, closes the socket.
   The state transition passes exclusively through the formally
   verified core (`executeBatch`).
2. **`CodexSupervisor.TcpReceiver`** (`supervisor/`) — Elixir
   GenServer. Listens on raw TCP (line framing), accepts verified
   workers, appends telemetry to
   `inbox/devFlow-finance-twin/telemetry.log`.
3. **`DevFlowTwin.TelemetryIngester`** (`supervisor/`) — Elixir
   GenServer. Watches the inbox via inotify, reads only the new
   bytes past its cursor, dispatches each line to the twin (the
   parse-to-ASP-solver / state-ledger hook is marked in the code).
4. **`DevFlowTwin.SpatialGraph`** (`supervisor/`) — the binary
   ingestion path. Parses a binary of 4 native 64-bit floats into
   quaternions and maps them into 4D space. The
   `update_digital_twin_spatial_graph/4` hook is a stub (logs the
   quaternion) — wire in the real spatial-graph update there.
5. **`Quaternion.hs`** — the 4D state vector (`QState`: Real, i, j,
   k) and `entangle`, the Hamilton product (non-commutative state
   fusion).

## Build

### The gate (local)

```bash
cabal build
```

GHC + the Liquid Haskell plugin checks `MobiusBridge`, `Quaternion`,
and `Main`. Verified on GHC 9.10.3 / Liquid Haskell 0.9.10.1.2:

- `MobiusBridge.hs` — `LIQUID: SAFE (203 constraints checked)`
- `Main.hs` — `LIQUID: SAFE (7 constraints checked)`
- `Quaternion.hs` — `SAFE (0 constraints)`

If any check fails, the build halts and no binary is emitted.

### Lean

```bash
lean lean/MobiusBridge.lean
```

Exit 0. `#check @cycle_preservation` confirms the theorem.

### Docker (the sovereign worker node)

```bash
docker build -t mobius-worker .
docker run --rm mobius-worker
```

Multi-stage: Alpine 3.19 builder (ghc/cabal/musl/gmp/z3) runs the
gate compile, then `FROM scratch` with only the static binary.
`ENTRYPOINT ["/mobius-worker"]`.

## Go live

Start the supervisor first (the worker's `connect` throws if
nothing is listening), then run the worker:

```bash
cd supervisor
mix deps.get
iex -S mix
# in IEx:
CodexSupervisor.TcpReceiver.start_link(8080)
DevFlowTwin.TelemetryIngester.start_link([])
```

Then run `mobius-worker` (local binary or Docker image). Confirm:
`inbox/devFlow-finance-twin/telemetry.log` fills with
`ROUND:|PENDING:|BUDGET:` lines, and the ingester logs each one.

## License

SNAPKITTY OPAQUE SOURCE LICENSE v1.0 — see `LICENSE`.
