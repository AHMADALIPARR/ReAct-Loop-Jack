defmodule PipelineTest do
  use ExUnit.Case, async: false
  alias DevFlowTwin.{Ledger, SpatialGraph, TelemetryIngester}

  test "binary quaternion ingestion changes graph and records distances" do
    {:ok, graph} = SpatialGraph.start_link(name: :graph_test)
    assert {:ok, [0,1]} = SpatialGraph.ingest(<<1.0::float-native-64,0.0::float-native-64,0.0::float-native-64,0.0::float-native-64,0.0::float-native-64,1.0::float-native-64,0.0::float-native-64,0.0::float-native-64>>, graph)
    state = SpatialGraph.snapshot(graph)
    assert map_size(state.nodes) == 2
    assert_in_delta state.edges[{0,1}], :math.sqrt(2), 1.0e-12
    assert {:error, :invalid_quaternion_stream} = SpatialGraph.ingest(<<1,2>>, graph)
    assert SpatialGraph.snapshot(graph) == state
    GenServer.stop(graph)
  end

  test "ledger validates invariants and state transitions" do
    {:ok, ledger} = Ledger.start_link(name: :ledger_test)
    assert {:ok, _} = Ledger.ingest("ROUND:0|PENDING:2|BUDGET:1", ledger)
    assert {:ok, _} = Ledger.ingest("ROUND:1|PENDING:1|BUDGET:2", ledger)
    assert {:error, :invalid_transition} = Ledger.ingest("ROUND:3|PENDING:1|BUDGET:2", ledger)
    assert {:error, :invariant} = Ledger.ingest("ROUND:2|PENDING:1|BUDGET:0", ledger)
    assert {:ok, _} = Ledger.ingest("ROUND:2|PENDING:0|BUDGET:3", ledger)
    assert Ledger.snapshot(ledger).complete
    assert Ledger.snapshot(ledger).accepted == 3
    GenServer.stop(ledger)
  end

  test "file ingestion buffers partial records and handles truncation" do
    {:ok, ledger} = Ledger.start_link(name: :file_ledger_test)
    dir = Path.join(System.tmp_dir!(), "mobius-file-test-#{System.unique_integer([:positive])}")
    path = Path.join(dir, "telemetry.log")
    File.mkdir_p!(dir)
    File.write!(path, "ROUND:0|PENDING:1|")
    {:ok, ingester} = TelemetryIngester.start_link(name: :file_ingester_test, path: path, ledger: ledger, interval: 60000)
    TelemetryIngester.poll(ingester)
    assert Ledger.snapshot(ledger).accepted == 0
    File.write!(path, "BUDGET:1\nROUND:1|PENDING:0|BUDGET:2\n", [:append])
    TelemetryIngester.poll(ingester)
    assert Ledger.snapshot(ledger).accepted == 2
    TelemetryIngester.poll(ingester)
    assert Ledger.snapshot(ledger).accepted == 2
    File.write!(path, "ROUND:0|PENDING:0|BUDGET:0\n")
    TelemetryIngester.poll(ingester)
    assert Ledger.snapshot(ledger).accepted == 3
    GenServer.stop(ingester)
    GenServer.stop(ledger)
    File.rm_rf!(dir)
  end

  test "interleaved workers keep independent state" do
    {:ok, ledger} = Ledger.start_link(name: :multi_ledger_test)
    assert {:ok, _} = Ledger.ingest_for("a", "ROUND:0|PENDING:2|BUDGET:1", ledger)
    assert {:ok, _} = Ledger.ingest_for("b", "ROUND:0|PENDING:1|BUDGET:8", ledger)
    assert {:ok, _} = Ledger.ingest_for("a", "ROUND:1|PENDING:1|BUDGET:2", ledger)
    assert {:ok, _} = Ledger.ingest_for("b", "ROUND:1|PENDING:0|BUDGET:9", ledger)
    assert Ledger.snapshot(ledger).streams["a"].budget == 2
    assert Ledger.snapshot(ledger).streams["b"].budget == 9
    GenServer.stop(ledger)
  end

  test "supervised TCP stream reaches ledger through journal" do
    port = CodexSupervisor.TcpReceiver.port()
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, port, [:binary, active: false])
    :ok = :gen_tcp.send(socket, "ROUND:0|PENDING:1|BUDGET:4\nROUND:1|PENDING:0|BUDGET:5\n")
    :gen_tcp.close(socket)
    wait(fn -> Ledger.snapshot().latest == %{round: 1, pending: 0, budget: 5} end, 40)
    assert Ledger.snapshot().complete
    assert Process.alive?(Process.whereis(CodexSupervisor.Supervisor))
  end
  defp wait(fun, 0), do: assert(fun.())
  defp wait(fun, n) do
    if fun.(), do: :ok, else: (Process.sleep(50); wait(fun, n-1))
  end
end
