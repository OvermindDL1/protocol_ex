defmodule Mix.Tasks.Compile.ProtocolEx do
  use Mix.Task

  @spec run(OptionParser.argv()) :: :ok
  def run(args) do
    # config = Mix.Project.config
    # Mix.Task.run "compile", args
    {opts, _, _} =
      OptionParser.parse(args, switches: [
            verbose: :boolean,
            print_protocol_ex: :boolean,
            no_protocol_tests: :boolean,
          ])

    verbose = opts[:verbose]

    opts =
      if opts[:no_protocol_tests] do
        opts
      else
        Keyword.put_new(opts, :protocol_tests, [])
      end

    if(verbose, do: IO.puts("Consolidating ProtocolEx's project-wide..."))
    ProtocolEx.consolidate_all([output_beam: true] ++ opts)
    if(verbose, do: IO.puts("Consolidating ProtocolEx's project-wide complete."))
    :ok
  end

  @doc """
  Cleans up consolidated protocols.
  """
  def clean do
    config = Mix.Project.config()
    File.rm_rf(Mix.Project.consolidation_path(config))
    :ok
  end
end
