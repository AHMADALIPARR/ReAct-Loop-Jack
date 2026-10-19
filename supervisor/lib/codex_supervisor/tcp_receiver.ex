defmodule CodexSupervisor.TcpReceiver do
  use GenServer
  require Logger

  @inbox_path "inbox/devFlow-finance-twin/telemetry.log"

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    # Bind raw TCP socket with line-based framing
    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info("Supervisor listening for verified Haskell workers on TCP #{port}")
    
    # Ensure the target inbox routing directory exists
    File.mkdir_p!(Path.dirname(@inbox_path))
    
    send(self(), :accept)
    {:ok, %{socket: listen_socket}}
  end

  def handle_info(:accept, %{socket: listen_socket} = state) do
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)
    
    # Spawn a lightweight worker process to handle the continuous stream
    Task.start(fn -> handle_stream(client_socket) end)
    
    # Immediately accept the next connection
    send(self(), :accept)
    {:noreply, state}
  end

  defp handle_stream(client_socket) do
    case :gen_tcp.recv(client_socket, 0) do
      {:ok, data} ->
        # Route raw string telemetry straight to the twin's inbox
        File.write!(@inbox_path, data, [:append])
        handle_stream(client_socket)
        
      {:error, :closed} ->
        Logger.info("Worker stream closed cleanly. Batch complete.")
    end
  end
end
