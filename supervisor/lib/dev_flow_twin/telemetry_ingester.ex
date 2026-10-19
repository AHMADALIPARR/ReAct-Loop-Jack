defmodule DevFlowTwin.TelemetryIngester do
  use GenServer
  require Logger
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  def poll(server \\ __MODULE__), do: GenServer.call(server, :poll)
  def init(opts) do
    path = Keyword.get(opts, :path, Application.get_env(:codex_supervisor, :telemetry_path, "inbox/devFlow-finance-twin/telemetry.log"))
    File.mkdir_p!(Path.dirname(path))
    interval = Keyword.get(opts, :interval, 250)
    Process.send_after(self(), :poll, interval)
    {:ok, %{path: path, offset: 0, inode: nil, partial: "", interval: interval, ledger: Keyword.get(opts, :ledger, DevFlowTwin.Ledger)}}
  end
  def handle_call(:poll, _from, s), do: {:reply, :ok, read_new(s)}
  def handle_info(:poll, s) do
    updated = read_new(s)
    Process.send_after(self(), :poll, s.interval)
    {:noreply, updated}
  end
  defp read_new(s) do
    case File.stat(s.path) do
      {:ok, stat} ->
        s = if stat.inode != s.inode or stat.size < s.offset, do: %{s | offset: 0, partial: "", inode: stat.inode}, else: s
        case File.open(s.path, [:read, :binary]) do
          {:ok, file} ->
            {:ok, _} = :file.position(file, s.offset)
            data = IO.binread(file, 65536)
            File.close(file)
            if is_binary(data) do
              parts = :binary.split(s.partial <> data, "\n", [:global])
              {lines, [partial]} = Enum.split(parts, -1)
              Enum.each(lines, fn line ->
                {worker, payload} = case Regex.run(~r/\AWORKER:([a-zA-Z0-9_-]{1,80})\|(.*)\z/, line) do
                  [_, id, content] -> {id, content}
                  _ -> {:default, line}
                end
                case DevFlowTwin.Ledger.ingest_for(worker, payload, s.ledger) do
                  {:ok, _} -> :ok
                  {:error, reason} -> Logger.warning("Rejected telemetry: #{inspect(reason)}")
                end
              end)
              partial = if byte_size(partial) > 4096, do: "", else: partial
              %{s | offset: s.offset + byte_size(data), partial: partial}
            else
              s
            end
          _ -> s
        end
      _ -> s
    end
  end
end
