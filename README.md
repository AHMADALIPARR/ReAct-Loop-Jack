# Mobius Bridge

Mobius Bridge combines the cycle-preservation state model in Lean and Liquid
Haskell with a TCP worker and an Elixir ingestion and spatial-graph service.
The counter transition is unchanged: increment round and synthetic budget,
decrement pending modules with saturation at zero.

## Worker and verification

```sh
cabal build
cabal run mobius-worker
```

The default build requires the Liquid Haskell plugin and runs its invariant
gate. Termination checking remains disabled as specified by the model.
Counters use arbitrary-precision Integer. The worker sends the terminal
zero-pending state as well as all preceding rounds.

For a native runtime build without invoking the proof plugin:

```sh
cabal build -f-verify
# Alternatively, with GHC and the network package installed:
mkdir -p .build
ghc -isrc -outputdir .build src/Main.hs -o .build/mobius-worker
```

The native build tests runtime behavior; it does not replace the Liquid Haskell
verification gate. The Lean source is `lean/MobiusBridge.lean`. Its mathematical
state-preservation theorem is distinct from deployment-specific timeout behavior.

## Supervisor and data flow

Requires Elixir 1.12 or newer, with no external Mix dependencies.

```sh
cd supervisor
mix test
iex -S mix
```

The application starts a real OTP supervision tree: worker task supervisor,
telemetry ledger, quaternion spatial graph, journal follower and TCP receiver.
The receiver binds to 127.0.0.1:8080. It validates record syntax and invariants,
appends worker-tagged records to a local journal and closes invalid streams.
The journal follower handles partial lines, truncation and file replacement.
It replays the journal on startup and validates each worker's transitions
independently, so concurrent streams do not overwrite one another's state.

```elixir
DevFlowTwin.Ledger.snapshot()
DevFlowTwin.SpatialGraph.ingest(<<1.0::float-native-64, 0.0::float-native-64,
  0.0::float-native-64, 0.0::float-native-64>>)
DevFlowTwin.SpatialGraph.snapshot()
```

The spatial graph stores quaternion samples as numbered nodes and Euclidean
distances between consecutive samples as edges. Invalid binary frames leave
the graph unchanged. Graph state is in memory; telemetry state is reconstructed
from the journal. The binary quaternion interface and textual counter interface
remain separate ingestion paths.

Native worker execution, Elixir integration tests and the unchanged Lean theorem
have been checked (Lean 4.19.0). The repaired
Liquid Haskell build has not been independently executed with the proof plugin;
the default gate remains enabled. Docker static linking is a separate build
target and has not been validated in this environment.

License: see LICENSE.
