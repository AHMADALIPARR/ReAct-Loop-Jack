defmodule CodexSupervisor.TcpReceiver do
  use GenServer
  def start_link(port), do: GenServer.start_link(__MODULE__, port, name: __MODULE__)
  def port, do: GenServer.call(__MODULE__, :port)
  def init(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, packet_size: 4096, active: false, reuseaddr: true, ip: {127,0,0,1}])
    acceptor = spawn_link(fn -> accept(socket) end)
    {:ok, %{socket: socket, acceptor: acceptor}}
  end
  def handle_call(:port, _from, s) do
    {:ok, {_, port}} = :inet.sockname(s.socket)
    {:reply, port, s}
  end
  def terminate(_, s), do: :gen_tcp.close(s.socket)
  defp accept(listener) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        {:ok, pid} = Task.Supervisor.start_child(CodexSupervisor.Workers, fn ->
          receive do {:socket, sock} -> stream(sock, "#{System.system_time(:microsecond)}-#{System.unique_integer([:positive])}") after 5000 -> :ok end
        end)
        :ok = :gen_tcp.controlling_process(socket, pid)
        send(pid, {:socket, socket})
        accept(listener)
      {:error, :closed} -> :ok
      {:error, reason} -> exit(reason)
    end
  end
  defp stream(socket, worker) do
    case :gen_tcp.recv(socket, 0, 60000) do
      {:ok, line} ->
        path = Application.get_env(:codex_supervisor, :telemetry_path, "inbox/devFlow-finance-twin/telemetry.log")
        File.mkdir_p!(Path.dirname(path))
        case DevFlowTwin.Ledger.parse(line) do
          {:ok, _} -> File.write!(path, "WORKER:" <> worker <> "|" <> line, [:append]); stream(socket, worker)
          {:error, _} -> :gen_tcp.close(socket)
        end
      {:error, _} -> :gen_tcp.close(socket)
    end
  end
end
