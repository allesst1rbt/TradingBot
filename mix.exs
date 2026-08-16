defmodule BotTrader.MixProject do
  use Mix.Project

  def project do
    [
      app: :bot_trader,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {BotTrader.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.16", only: :test},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, "~> 0.20"}
    ]
  end
end
