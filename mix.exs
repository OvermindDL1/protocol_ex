defmodule ProtocolEx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :protocol_ex,
      version: "0.3.4",
      elixir: "~> 1.4",
      description: description(),
      package: package(),
      docs: [
          #logo: "path/to/logo.png",
          extras: ["README.md"],
          main: "readme",
          assets: "deps/makedown/priv/ex_doc/assets",
          # Extra CSS
          before_closing_head_tag: fn _ -> ~S(<link rel="stylesheet" href="assets/makedown.css"/>) end,
          # Extra Javascript
          before_closing_body_tag: fn _ -> ~S(<script src="assets/makedown.js"></script>) end
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
      # Optional dependencies
      {:stream_data, "~> 0.3.0", optional: true, only: [:dev, :test]},
      # Development and documentation only
      {:makeup, "~> 0.2.0", only: [:dev]},
      {:makeup_elixir, "~> 0.2.0", only: [:dev]},
      {:makedown, "~> 0.2.0", only: [:dev]},
      {:ex_doc, "~> 0.16.3", only: [:dev]},
      # Testing only
      {:cortex, "~> 0.2.0", only: [:test]},
      {:benchee, "~> 0.9.0", only: [:test]},
      {:numbers, "~> 5.1", only: [:test]},
      {:decimal, "~> 1.3", only: [:test]}
    ]
  end
end
