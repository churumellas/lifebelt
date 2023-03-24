import Config

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :logger, level: :warn

config :lifebelt, Lifebelt.Test.Repo,
  migration_lock: false,
  name: Lifebelt.Test.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  password: "postgres",
  username: "postgres",
  priv: "test/support/postgres",
  url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/oban_test"

config :lifebelt,
  ecto_repos: [Lifebelt.Test.Repo]
