defmodule CodexSupervisor.Application do
  use Application
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: CodexSupervisor.Workers},
      DevFlowTwin.Ledger,
      DevFlowTwin.SpatialGraph,
      DevFlowTwin.TelemetryIngester,
      {CodexSupervisor.TcpReceiver, Application.get_env(:codex_supervisor, :port, 8080)}
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: CodexSupervisor.Supervisor)
  end
end
