ExUnit.configure(exclude: [bench: true])
ExUnit.start()


defmodule MyStruct do
  defstruct a: 42
end

import ProtocolEx

defmodule EmbTesting do
  defprotocol_ex Emb do
    def add(a)
  end

  defimpl_ex Atom, a when is_atom(a), for: Emb do
    def add(a), do: a
  end
  defimpl_ex Binary, b when is_binary(b), for: EmbTesting.Emb do
    def add(b), do: b
  end
end

## This can't be in the same file as the module definition as the module
## is not compiled by the time this is ready.
#defimpl_ex Integer, i when is_integer(i), for: EmbTesting.Emb do
#  def add(a), do: a+1
#end

defmodule MoreEmbTesting do
  defimpl_ex Float, f when is_float(f), for: EmbTesting.Emb do
    def add(a), do: a+1.0
  end
end

defprotocol_ex Blah do
  def empty()
  def succ(a)
  def add(a, b)
  def map(a, f) when is_function(f, 1)

  def a_fallback(a), do: inspect(a)
end

defimpl_ex Integer, i when is_integer(i), for: Blah do
  @priority 1
  def empty(), do: 0
  defmacro succ(ivar), do: quote(do: unquote(ivar)+1)
  def add(i, b), do: i+b
  def map(i, f), do: f.(i)

  def a_fallback(i), do: "Integer: #{i}"
end

defimplEx TaggedTuple.Vwoop, {Vwoop, i} when is_integer(i), for: Blah do
  def empty(), do: {Vwoop, 0}
  def succ({Vwoop, i}), do: {Vwoop, i+1}
  def add({Vwoop, i}, b), do: {Vwoop, i+b}
  def map({Vwoop, i}, f), do: {Vwoop, f.(i)}
end

defimplEx MineOlStruct, %MyStruct{}, for: Blah do
  def empty(), do: %MyStruct{a: extra_func1(0)}
  def succ(s), do: %{s | a: s.a+1}
  def add(s, b), do: %{s | a: s.a+b}
  def map(s, f), do: %{s | a: f.(s.a)}
  def extra_func0(), do: priv_func0()
  def extra_func1(a), do: priv_func1(a)
  def extra_func2(a, b), do: priv_func2(a, b)
  defp priv_func0, do: :undefined
  defp priv_func1(a), do: a
  defp priv_func2(a, b), do: a+b
end

defmodule Resolver do
  ProtocolEx.resolveProtocolEx(Blah, [
    Integer,
    TaggedTuple.Vwoop,
    MineOlStruct,
  ], print_protocol_ex: true)
end

defmodule Mod1 do
  defmodule Mod11 do
    defmodule Mod111 do
      defstruct a: 42
    end
  end
end

defprotocol_ex ModProto do
  def blah(a)
  def bloop(a)
end

defimpl_ex Greater, %Mod1.Mod11.Mod111{a: a} when a>=0, for: ModProto do
  def blah(%Mod1.Mod11.Mod111{a: a}), do: %Mod1.Mod11.Mod111{a: a - 1}
  def bloop(v), do: v
end
alias Mod1.Mod11
defimpl_ex Zero, %Mod11.Mod111{a: 0}, for: ModProto do
  def blah(%Mod11.Mod111{a: a}), do: %Mod11.Mod111{a: a}
  alias Mod11.Mod111
  def bloop(%Mod111{a: a}), do: %Mod111{a: a}
end
alias Mod11.Mod111
defimpl_ex Lesser, %Mod111{a: a} when a<0, for: ModProto do
  def blah(%Mod111{a: a}), do: %Mod111{a: a + 1}
  def bloop(v), do: v
end
defmodule ResolverMod do
  ProtocolEx.resolveProtocolEx(ModProto, [Zero, Greater, Lesser])
end


defprotocolEx Expro.Proto do
  def foo(p)
end

alias Expro.Proto

defimplEx Foo, true, for: Proto do
  def foo(_p), do: true
end

defmodule ResolverExpro do
  ProtocolEx.resolveProtocolEx(Expro.Proto, [Foo])
end


defprotocol_ex Defaults do
  def succ(a, b \\ 1)
end

defimpl_ex Integer, i when is_integer(i), for: Defaults do
  def succ(a, b), do: a + b
end

defmodule DefaultResolver do
  ProtocolEx.resolveProtocolEx(Defaults, [Integer])
end


# # TODO:  Actually I do have to wrap it up now, will not work until they actually exist in `.ex` files now...
# # Only wrapping everything up in modules to prevent having to make more `.ex` files
# defmodule Testering do
#
#   defprotocol_ex Blah do
#     def empty()
#     def succ(a)
#     def add(a, b)
#     def map(a, f) when is_function(f, 1)
#
#     def a_fallback(a), do: inspect(a)
#   end
#
#   # Extending and properties
#   defprotocolEx Functor, as: v do
#     def map(v, f)
#
#     deftest identity do
#       StreamData.check_all(prop_generator(), [initial_seed: :os.timestamp()], fn v ->
#         if v === map(v, &(&1)) do
#           {:ok, v}
#         else
#           {:error, v}
#         end
#       end)
#     end
#
#     deftest composition do
#       f = fn x -> x end
#       g = fn x -> x end
#       StreamData.check_all(prop_generator(), [initial_seed: :os.timestamp()], fn v ->
#         if map(v, fn x -> f.(g.(x)) end) === map(map(v, g), f) do
#           {:ok, v}
#         else
#           {:error, v}
#         end
#       end)
#     end
#   end
#
# end
#
# defmodule Testering1 do
#   alias Testering.Blah
#   alias Testering.Functor
#
#   defimpl_ex Integer, i when is_integer(i), for: Blah do
#     @priority 1
#     def empty(), do: 0
#     defmacro succ(ivar), do: quote(do: unquote(ivar)+1)
#     def add(i, b), do: i+b
#     def map(i, f), do: f.(i)
#
#     def a_fallback(i), do: "Integer: #{i}"
#   end
#
#   defimplEx TaggedTuple.Vwoop, {Vwoop, i} when is_integer(i), for: Blah do
#     def empty(), do: {Vwoop, 0}
#     def succ({Vwoop, i}), do: {Vwoop, i+1}
#     def add({Vwoop, i}, b), do: {Vwoop, i+b}
#     def map({Vwoop, i}, f), do: {Vwoop, f.(i)}
#   end
#
#   defimplEx MineOlStruct, %MyStruct{}, for: Blah do
#     def empty(), do: %MyStruct{a: 0}
#     def succ(s), do: %{s | a: s.a+1}
#     def add(s, b), do: %{s | a: s.a+b}
#     def map(s, f), do: %{s | a: f.(s.a)}
#   end
#
#   # Functor test
#
#   defimplEx Integer, i when is_integer(i), for: Functor, inline: [map: 2] do
#     def prop_generator(), do: StreamData.integer()
#     def map(i, f) when is_integer(i), do: f.(i)
#   end
#
#   defimplEx List, l when is_list(l), for: Functor do
#     def prop_generator(), do: StreamData.list_of(StreamData.integer())
#     def map([], _f), do: []
#     def map([h | t], f), do: [f.(h) | map(t, f)]
#   end
# end
#
# defmodule TesteringResolved do # This thing could easily become a compiler plugin instead of an explicit call
#   alias Testering.Blah
#   alias Testering.Functor
#
#   ProtocolEx.resolveProtocolEx(Blah, [
#     Integer,
#     TaggedTuple.Vwoop,
#     MineOlStruct,
#   ])
#
#   ProtocolEx.resolve_protocol_ex(Functor, [
#     Integer,
#     List,
#   ])
#
#   # Now supporting auto-detection of anything already compiled!
#   # (So when inline at compile-time like this then require first to make sure they are already compiled)
#   # require Blah.Integer
#   # require Blah.TaggedTuple.Vwoop
#   # require Blah.MineOlStruct
#   # ProtocolEx.resolveProtocolEx(Blah) # Without a list it auto-detects based on what is already compiled
#
#   0                  = Blah.Integer.empty()
#   {Vwoop, 0}         = Blah.TaggedTuple.Vwoop.empty()
#   %MyStruct{a: 0}    = Blah.MineOlStruct.empty()
#
#   0                  = Blah.empty(42)
#   {Vwoop, 0}         = Blah.empty({Vwoop, 42})
#   %MyStruct{a: 0}    = Blah.empty(%MyStruct{a: 42})
#
#   43                 = Blah.succ(42)
#   {Vwoop, 43}        = Blah.succ({Vwoop, 42})
#   %MyStruct{a: 43}   = Blah.succ(%MyStruct{a: 42})
#
#   47                 = Blah.add(42, 5)
#   {Vwoop, 47}        = Blah.add({Vwoop, 42}, 5)
#   %MyStruct{a: 47}   = Blah.add(%MyStruct{a: 42}, 5)
#
#   "Integer: 42"      = Blah.a_fallback(42)
#   "{Vwoop, 42}"      = Blah.a_fallback({Vwoop, 42})
#   "%MyStruct{a: 42}" = Blah.a_fallback(%MyStruct{a: 42})
#
#   43                 = Blah.map(42, &(&1+1))
#   {Vwoop, 43}        = Blah.map({Vwoop, 42}, &(&1+1))
#   %MyStruct{a: 43}   = Blah.map(%MyStruct{a: 42}, &(&1+1))
# end
