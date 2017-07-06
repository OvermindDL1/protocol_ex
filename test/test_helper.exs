ExUnit.start()


import ProtocolEx

# Only wrapping everything up in modules to prevent having to make more `.ex` files
defmodule Testering do

  defprotocolEx Blah do
    def empty(a)
    def succ(a)
    def add(a, b)
  end

end

defmodule Testering1 do
  defimplEx Integer, i when is_integer(i), for: Testering.Blah do
    def empty(_), do: 0
    def succ(i), do: i+1
    def add(i, b), do: i+b
  end
end

defmodule MyStruct do
  defstruct a: 42
end

defmodule Testering2 do
  defimplEx TaggedTuple.Vwoop, {Vwoop, i} when is_integer(i), for: Testering.Blah do
    def empty(_), do: {Vwoop, 0}
    def succ({Vwoop, i}), do: {Vwoop, i+1}
    def add({Vwoop, i}, b), do: {Vwoop, i+b}
  end

  defimplEx MineOlStruct, %MyStruct{}, for: Testering.Blah do
    def empty(_), do: %MyStruct{a: 0}
    def succ(s), do: %{s | a: s.a+1}
    def add(s, b), do: %{s | a: s.a+b}
  end
end

defmodule TesteringResolved do # This thing could easily become a compiler plugin instead of an explicit call
  ProtocolEx.resolveProtocolEx(Testering.Blah, [
    Integer,
    TaggedTuple.Vwoop,
    MineOlStruct,
  ])
end
