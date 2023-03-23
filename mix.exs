defmodule Lifebelt.MixProject do
  use Mix.Project

  def project do
    [
      app: :lifebelt,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oban, "~> 2.14.2"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:ecto_sql, "~> 3.6"}
    ]
  end
end
