defmodule DevFlowTwin.Ledger do
  use GenServer
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  def snapshot(server \\ __MODULE__), do: GenServer.call(server, :snapshot)
  def ingest(line, server \\ __MODULE__) when is_binary(line), do: ingest_for(:default, line, server)
  def ingest_for(worker, line, server \\ __MODULE__), do: GenServer.call(server, {:ingest, worker, line})

  def parse(line) do
    case Regex.run(~r/\AROUND:(\d+)\|PENDING:(\d+)\|BUDGET:(\d+)\z/, String.trim(line)) do
      [_, r, p, b] ->
        state = %{round: String.to_integer(r), pending: String.to_integer(p), budget: String.to_integer(b)}
        if state.pending == 0 or state.budget > 0, do: {:ok, state}, else: {:error, :invariant}
      _ -> {:error, :malformed_telemetry}
    end
  end

  def init(_), do: {:ok, %{latest: nil, streams: %{}, accepted: 0, rejected: 0, complete: false}}
  def handle_call(:snapshot, _from, state), do: {:reply, state, state}
  def handle_call({:ingest, worker, line}, _from, state) do
    with {:ok, next} <- parse(line), :ok <- transition(Map.get(state.streams, worker), next) do
      updated = %{state | latest: next, streams: Map.put(state.streams, worker, next), accepted: state.accepted + 1, complete: next.pending == 0}
      {:reply, {:ok, next}, updated}
    else
      {:error, reason} -> {:reply, {:error, reason}, %{state | rejected: state.rejected + 1}}
    end
  end
  defp transition(nil, _), do: :ok
  defp transition(_, %{round: 0}), do: :ok
  defp transition(old, next) do
    if next.round == old.round + 1 and next.pending == max(old.pending - 1, 0) and next.budget == old.budget + 1,
      do: :ok, else: {:error, :invalid_transition}
  end
end
