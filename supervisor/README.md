# CodexSupervisor — Elixir TCP receiver + twin ingester

The supervisor mesh for the MobiusBridge Haskell worker.

## The pipeline

1. **Haskell worker** (`mobius-worker`) — connects to `127.0.0.1:8080`,
   streams `ROUND:<n>|PENDING:<n>|BUDGET:<n>` lines, closes the socket.
2. **`CodexSupervisor.TcpReceiver`** (user's module, verbatim) — a
   GenServer that listens on raw TCP (line-based framing), accepts
   verified Haskell workers, and appends their telemetry lines to
   `inbox/devFlow-finance-twin/telemetry.log`.
3. **`DevFlowTwin.TelemetryIngester`** (user's module, verbatim) — a
   GenServer that watches `inbox/devFlow-finance-twin/` via inotify
   (`file_system`), reads only the new bytes past its cursor (no
   re-read, no memory bloat), and dispatches each line to the twin
   (currently logs it; the parse-to-ASP-solver / state-ledger hook is
   marked in the code).
4. **`DevFlowTwin.SpatialGraph`** — the BINARY ingestion path (separate
   from the text telemetry log). `extract_quaternion/1` (user's,
   verbatim) parses a binary of 4 native 64-bit floats (a, b, c, d)
   and maps each quaternion into 4D space. `update_digital_twin_spatial_graph/4`
   is an assistant-added stub (logs the quaternion) — wire in the real
   spatial-graph update there. Feed it via `DevFlowTwin.SpatialGraph.ingest(binary)`.

## The quaternion (Haskell)

`src/Quaternion.hs` (user's code, verbatim) defines the 4D state vector
`QState` (Real, i, j, k) and `entangle` — the Hamilton product,
non-commutative state fusion. It is a module in the `mobius-worker`
package (`other-modules`).

## Run it

```bash
cd supervisor
mix deps.get   # no deps, but ensures the project is set up
iex -S mix
```

Then, in the IEx shell:

```elixir
CodexSupervisor.TcpReceiver.start_link(8080)
DevFlowTwin.TelemetryIngester.start_link([])
```

The receiver listens on port 8080 (the port the Haskell worker's
`connectSupervisor "127.0.0.1" "8080"` dials). Each worker connection
gets a lightweight Task that appends every line to the inbox log.
When the worker closes the socket, the task logs "Worker stream
closed cleanly. Batch complete."

The ingester starts at the log's current byte offset (it does not
re-read history on boot), then follows inotify `:modified` events and
dispatches only the new bytes.

## The loop

1. Start the receiver (above) — it listens on 8080.
2. Run the Haskell worker (`mobius-worker`) — it connects, streams
   `ROUND:<n>|PENDING:<n>|BUDGET:<n>` lines, closes the socket.
3. The receiver appends each line to the inbox log.

The Haskell worker will fail at runtime (`connect` throws) if the
receiver is not listening — start the receiver first. The Liquid
Haskell gate is about compilation (the invariant), not about the
supervisor being up.
