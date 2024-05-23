import ProtocolEx

defimplEx Integer, i when is_integer(i), for: Blah do
  @priority 1
  def empty(_), do: 0
  def succ(i), do: i+1
  def add(i, b), do: i+b
  def map(i, f), do: f.(i)

  def a_fallback(i), do: "Integer: #{i}"
end

defmodule SubModule.MyStruct do
  defstruct a: 42
end

defimplEx TaggedTuple.Vwoop, {Vwoop, i} when is_integer(i), for: Blah do
  def empty(_), do: {Vwoop, 0}
  def succ({Vwoop, i}), do: {Vwoop, i+1}
  def add({Vwoop, i}, b), do: {Vwoop, i+b}
  def map({Vwoop, i}, f), do: {Vwoop, f.(i)}
end

alias SubModule.MyStruct
defimplEx MineOlStruct, %MyStruct{}, for: Blah do
  def empty(_), do: %SubModule.MyStruct{a: 0}
  def succ(s), do: %{s | a: s.a+1}
  def add(s, b), do: %{s | a: s.a+b}
  def map(s, f), do: %{s | a: f.(s.a)}
end

defimplEx Integer, i when is_integer(i), for: Bloop.Bloop do
  def get(i), do: {:integer, i}
  def get_with_fallback(i), do: {:integer, i}
end
