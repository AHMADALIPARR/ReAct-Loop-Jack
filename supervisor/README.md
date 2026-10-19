# Mobius supervisor

Run `mix test` to exercise graph updates, transition validation, partial journal
records, truncation, concurrent workers and the live TCP receiver.

Run `iex -S mix` to start the OTP supervision tree. The TCP endpoint is
127.0.0.1:8080. Query `DevFlowTwin.Ledger.snapshot()` for worker states and
`DevFlowTwin.SpatialGraph.snapshot()` for quaternion nodes and edges.

The journal defaults to `inbox/devFlow-finance-twin/telemetry.log`. Set the
`:codex_supervisor` application keys `:port` and `:telemetry_path` to override
the port or storage location. Binary quaternion samples are supplied explicitly
through `SpatialGraph.ingest/1`; text telemetry is never reinterpreted as floats.
