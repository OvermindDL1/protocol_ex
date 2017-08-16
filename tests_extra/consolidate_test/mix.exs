defmodule ConsolidateTest.Mixfile do
  use Mix.Project

  def project do
    [
      app: :consolidate_test,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      compilers: Mix.compilers ++ [:protocol_ex],
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
      {:protocol_ex, path: "../.."},
    ]
  end
end
