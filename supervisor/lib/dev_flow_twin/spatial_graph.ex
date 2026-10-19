defmodule DevFlowTwin.SpatialGraph do
  @moduledoc """
  Binary quaternion stream -> digital twin spatial graph.

  The user's `extract_quaternion/1` (verbatim) parses a binary of
  4 native 64-bit floats (a, b, c, d) + rest, maps each quaternion
  into 4D space, and recurses. This is the BINARY ingestion path
  (sensor / spatial stream), separate from the TelemetryIngester's
  TEXT telemetry-log path.

  The `update_digital_twin_spatial_graph/4` called below is an
  ASSISTANT-ADDED stub (the user's code calls it but does not define
  it). It logs the quaternion so the module compiles and the pipeline
  runs. Wire in the real spatial-graph update here.
  """

  require Logger

  defp extract_quaternion(<<a::float-native-size(64),
                             b::float-native-size(64),
                             c::float-native-size(64),
                             d::float-native-size(64),
                             rest::binary>>) do

    # The state is instantly mapped into 4D space
    update_digital_twin_spatial_graph(a, b, c, d)

    extract_quaternion(rest)
  end
  defp extract_quaternion(<<>>), do: :ok

  # ASSISTANT-ADDED stub (see moduledoc). Replace with the real
  # digital-twin spatial-graph update.
  defp update_digital_twin_spatial_graph(a, b, c, d) do
    Logger.debug("[SpatialGraph] quaternion: #{a}, #{b}, #{c}, #{d}")
    :ok
  end

  @doc """
  Entry point: feed a binary quaternion stream into the spatial graph.
  """
  def ingest(binary) when is_binary(binary) do
    extract_quaternion(binary)
  end
end
