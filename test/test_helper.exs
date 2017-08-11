ExUnit.configure(exclude: [bench: true])
ExUnit.start()


import ProtocolEx

# Only wrapping everything up in modules to prevent having to make more `.ex` files
defmodule Testering do

  defprotocolEx Blah do
    def empty(a)
    def succ(a)
    def add(a, b)
    def map(a, f) when is_function(f, 1)

    def a_fallback(a), do: inspect(a)
  end

end

defmodule Testering1 do
  alias Testering.Blah

  defimplEx Integer, i when is_integer(i), for: Blah do
    def empty(_), do: 0
    def succ(i), do: i+1
    def add(i, b), do: i+b
    def map(i, f), do: f.(i)

    def a_fallback(i), do: "Integer: #{i}"
  end
end

defmodule MyStruct do
  defstruct a: 42
end

defmodule Testering2 do
  alias Testering.Blah

  defimplEx TaggedTuple.Vwoop, {Vwoop, i} when is_integer(i), for: Blah do
    def empty(_), do: {Vwoop, 0}
    def succ({Vwoop, i}), do: {Vwoop, i+1}
    def add({Vwoop, i}, b), do: {Vwoop, i+b}
    def map({Vwoop, i}, f), do: {Vwoop, f.(i)}
  end

  defimplEx MineOlStruct, %MyStruct{}, for: Blah do
    def empty(_), do: %MyStruct{a: 0}
    def succ(s), do: %{s | a: s.a+1}
    def add(s, b), do: %{s | a: s.a+b}
    def map(s, f), do: %{s | a: f.(s.a)}
  end
end

defmodule TesteringResolved do # This thing could easily become a compiler plugin instead of an explicit call
  alias Testering.Blah

  ProtocolEx.resolveProtocolEx(Blah, [
    Integer,
    TaggedTuple.Vwoop,
    MineOlStruct,
  ])

  0                  = Blah.empty(42)
  {Vwoop, 0}         = Blah.empty({Vwoop, 42})
  %MyStruct{a: 0}    = Blah.empty(%MyStruct{a: 42})

  43                 = Blah.succ(42)
  {Vwoop, 43}        = Blah.succ({Vwoop, 42})
  %MyStruct{a: 43}   = Blah.succ(%MyStruct{a: 42})

  47                 = Blah.add(42, 5)
  {Vwoop, 47}        = Blah.add({Vwoop, 42}, 5)
  %MyStruct{a: 47}   = Blah.add(%MyStruct{a: 42}, 5)

  "Integer: 42"      = Blah.a_fallback(42)
  "{Vwoop, 42}"      = Blah.a_fallback({Vwoop, 42})
  "%MyStruct{a: 42}" = Blah.a_fallback(%MyStruct{a: 42})

  43                 = Blah.map(42, &(&1+1))
  {Vwoop, 43}        = Blah.map({Vwoop, 42}, &(&1+1))
  %MyStruct{a: 43}   = Blah.map(%MyStruct{a: 42}, &(&1+1))
end
