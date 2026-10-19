defmodule DevFlowTwin.SpatialGraph do
  use GenServer
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  def ingest(binary, server \\ __MODULE__), do: GenServer.call(server, {:ingest, binary})
  def snapshot(server \\ __MODULE__), do: GenServer.call(server, :snapshot)
  def update_digital_twin_spatial_graph(a, b, c, d), do: ingest(<<a::float-native-64, b::float-native-64, c::float-native-64, d::float-native-64>>)

  def init(_), do: {:ok, %{nodes: %{}, edges: %{}, next_id: 0}}
  def handle_call(:snapshot, _from, state), do: {:reply, state, state}
  def handle_call({:ingest, binary}, _from, state) when is_binary(binary) and rem(byte_size(binary), 32) == 0 do
    case decode(binary, []) do
      {:ok, quaternions} ->
        {updated, ids} = Enum.reduce(quaternions, {state, []}, fn q, {s, ids} ->
          id = s.next_id
          edges = if id > 0 do
            old = Map.fetch!(s.nodes, id - 1)
            distance = Enum.zip(Tuple.to_list(old), Tuple.to_list(q)) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + (x-y)*(x-y) end)
            Map.put(s.edges, {id - 1, id}, :math.sqrt(distance))
          else
            s.edges
          end
          {%{s | nodes: Map.put(s.nodes, id, q), edges: edges, next_id: id + 1}, [id | ids]}
        end)
        {:reply, {:ok, Enum.reverse(ids)}, updated}
      error -> {:reply, error, state}
    end
  end
  def handle_call({:ingest, _}, _from, state), do: {:reply, {:error, :invalid_quaternion_stream}, state}
  defp decode(<<>>, acc), do: {:ok, Enum.reverse(acc)}
  defp decode(<<a::float-native-64, b::float-native-64, c::float-native-64, d::float-native-64, rest::binary>>, acc),
    do: decode(rest, [{a,b,c,d} | acc])
  defp decode(_, _), do: {:error, :nonfinite_or_invalid_float}
end
