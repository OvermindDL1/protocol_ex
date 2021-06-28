defmodule ProtocolEx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :protocol_ex,
      version: "0.4.4",
      elixir: "~> 1.4",
      description: description(),
      package: package(),
      docs: [
        extras: ["README.md"],
        main: "readme",
        #markdown_processor: ExDocMakeup,
        #markdown_processor_options: [
        #  lexer_options: %{
        #    "elixir" => [
        #      extra_declarations: [
        #        "defimplEx", "defimpl_ex",
        #        "defprotocolEx", "defprotocol_ex"],
        #      extra_def_like: ["deftest"]]
        #  }
        #]
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
      ] ++ if(Mix.env() in [:test], do: [:stream_data], else: [])
    ]
  end

  defp deps do
    [
      # Optional dependencies
      {:stream_data, "~> 0.4.2", optional: true, only: [:dev, :test]},
       # Documentation
      {:ex_doc, ">= 0.19.0-rc", only: [:dev]},
      #{:ex_doc_makeup, ">= 0.1.0", only: [:dev]},
      # Testing only
      {:cortex, "~> 0.5.0", only: [:test]},
      {:benchee, "~> 0.14.0", only: [:test]},
      {:numbers, "~> 5.1", only: [:test]},
      {:decimal, "~> 1.3", only: [:test]}
    ]
  end
end
