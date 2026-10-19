import Config
config :codex_supervisor, port: 0,
  telemetry_path: Path.join(System.tmp_dir!(), "mobius-tests-#{System.pid()}/telemetry.log")
