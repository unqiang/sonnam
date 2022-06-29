defmodule Sonnam.MixProject do
  use Mix.Project

  def project do
    [
      app: :sonnam,
      version: "0.1.0",
      elixir: "~> 1.11",
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
      {:tzdata, "~> 1.1"},
      {:redix, "~> 1.1"},
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.3"},
      {:strukt, "~> 0.3"},
      {:mime, "~> 2.0"},
      {:nimble_pool, "~> 0.2"},
      {:observer_cli, "~> 1.7"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
