defmodule ProtocolEx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :protocol_ex,
      version: "0.1.0",
      elixir: "~> 1.4",
      description: description(),
      package: package(),
      docs: [
          #logo: "path/to/logo.png",
          extras: ["README.md"],
          main: "readme",
          ],
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
    ]
  end

  def description do
    """
    Extended Protocol library using Matchers
    """
  end

  def package do
    [
      licenses: ["MIT"],
      name: :protocol_ex,
      maintainers: ["OvermindDL1"],
      links: %{"Github" => "https://github.com/OvermindDL1/protocol_ex"}
    ]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [
        # :logger,
      ],
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.16.2", only: [:dev]},
    ]
  end
end
