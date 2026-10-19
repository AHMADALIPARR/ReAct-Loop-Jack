defmodule DevFlowTwin.TelemetryIngester do
  use GenServer
  require Logger

  @target_dir "inbox/devFlow-finance-twin"
  @target_file "#{@target_dir}/telemetry.log"

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    File.mkdir_p!(@target_dir)

    # 1. Bind to the OS-level file events (inotify)
    {:ok, watcher_pid} = FileSystem.start_link(dirs: [@target_dir])
    FileSystem.subscribe(watcher_pid)

    # 2. Determine the initial byte offset to avoid re-reading historical data on boot
    initial_offset = 
      case File.stat(@target_file) do
        {:ok, %{size: size}} -> size
        _ -> 0
      end

    Logger.info("[Twin] Ingestion engine locked to #{@target_dir} starting at byte #{initial_offset}")
    
    {:ok, %{offset: initial_offset, watcher: watcher_pid}}
  end

  # 3. Intercept OS-level modification events
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    # Only react if the specific telemetry ledger was modified
    if String.ends_with?(to_string(path), "telemetry.log") and :modified in events do
      new_state = process_new_bytes(state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:file_event, _watcher_pid, :stop}, state), do: {:noreply, state}

  # 4. Pure byte-cursor read (Zero memory bloat)
  defp process_new_bytes(%{offset: current_offset} = state) do
    case File.open(@target_file, [:read, :binary]) do
      {:ok, file} ->
        # Jump directly to where we left off
        :file.position(file, current_offset)
        new_data = IO.read(file, :all)
        File.close(file)

        if new_data != :eof and new_data != "" do
          dispatch_to_twin(new_data)
          
          # Advance the state machine's cursor
          new_offset = current_offset + byte_size(new_data)
          %{state | offset: new_offset}
        else
          state
        end
      _ ->
        state
    end
  end

  # 5. Route the ingested strings into the active twin architecture
  defp dispatch_to_twin(data) do
    data
    |> String.split("\n", trim: true)
    |> Enum.each(fn line ->
      # Here is where you parse the "ROUND:1|PENDING:50" payload 
      # and cast it directly into your ASP solver or state ledger.
      Logger.debug("[Twin Ingest] Processed: #{line}")
    end)
  end
end
