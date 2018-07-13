import ProtocolEx

defprotocolEx Blah do
  @moduledoc "Test moduledoc"

  @doc "Test empty doc"
  #@doc since: "1.0.0"
  def empty(a)
  def succ(a)
  def add(a, b)
  def map(a, f) when is_function(f, 1)

  def a_fallback(a), do: inspect(a)

  deftest identity do
    id = fn x -> x end
    StreamData.check_all(StreamData.integer(), [initial_seed: :os.timestamp()], fn a ->
      v = empty(nil)
      if map(v, id) === v do # and a<10 do
        {:ok, a}
      else
        {:error, a}
      end
    end)
  end
end

defmodule Bloop do
  defprotocolEx Bloop do
    def get(thing)
    def get_with_fallback(thing), do: {:fallback, thing}
  end
end

#defmodule Bloop.Bloop do
#  def blah do
#  end
#end
