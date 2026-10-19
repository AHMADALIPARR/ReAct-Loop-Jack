defmodule CodexSupervisor.MixProject do
  use Mix.Project

  # ASSISTANT-ADDED scaffolding (not the user's code): the minimal
  # Mix project so the TcpReceiver module compiles and runs.
  # The TcpReceiver module itself (lib/codex_supervisor/tcp_receiver.ex)
  # is the user's, verbatim.
  def project do
    [
      app: :codex_supervisor,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:file_system, "~> 1.0"}
    ]
  end
end
