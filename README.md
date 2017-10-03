# ProtocolEx

Extended Protocol library.

Performs matching for protocol implentations instead of being limited to certain base types as in standard Elixir Protocols.

## Installation

[Available in Hex](https://hex.pm/packages/protocol_ex) with [Documentation](https://hexdocs.pm/protocol_ex), the package can be installed
by adding `:protocol_ex` to your list of dependencies in `mix.exs`:

```elixir
{:protocol_ex, "~> 0.2.0"},
```

## Usage

For auto-consolidation add the compiler to your `mix.exs` definition like (make certain it comes after the built-in elixir compiler):

```elixir
def project do
  [
    # ...
    compilers: Mix.compilers ++ [:protocol_ex],
    # ...
  ]
end
```

### Setup

The below assumes:

```elixir
import ProtocolEx
```

### `defprotocolEx/2`

`defprotocolEx/2` is used like `defmodule` in that it takes a module name to become and the body. The body can contains plain function heads like:

```elixir
def something(a)
def blah(a, b)
```

Or it can contains full bodies:

```elixir
def bloop(a) do
  to_string(a)
end
```

Plain heads **must** be implemented in an implementation, not to do so will raise an error.

Full body functions supply the fallback, if an implementation does not supply an implementation of it then it will fall back to the fallback implementation.

Inside a `defprotocolEx/2` you are able to use `deftest` to run some tests at compile time to make certain that the implementations follow necessary rules.

#### Example

```elixir
defprotocolEx Blah do
  def empty() # Transformed to 1-arg that matches on based on the implementation, but ignored otherwise
  def succ(a)
  def add(a, b)
  def map(a, f) when is_function(f, 1)

  def a_fallback(a), do: inspect(a)
end
```

##### deftest example

In this example each implementation must also define a `prop_generator` that returns a StreamData generator to generate the types of that implementation, such as for lists:  `def prop_generator(), do: StreamData.list_of(StreamData.integer())`

```elixir
defprotocolEx Functor do
  def map(v, f)

  deftest identity do
    StreamData.check_all(prop_generator(), [initial_seed: :os.timestamp()], fn v ->
      if v === map(v, &(&1)) do
        {:ok, v}
      else
        {:error, v}
      end
    end)
  end

  deftest composition do
    f = fn x -> x end
    g = fn x -> x end
    StreamData.check_all(prop_generator(), [initial_seed: :os.timestamp()], fn v ->
      if map(v, fn x -> f.(g.(x)) end) === map(map(v, g), f) do
        {:ok, v}
      else
        {:error, v}
      end
    end)
  end
end
```

### `defimplEx/4`

`defimplEx/4` takes a unique name for this implementation for the given protocol first, then a normal elixir match expression second, then `[for: ProtocolName]` for a given protocol, and lastly the body.

#### Example

```elixir
defimplEx Integer, i when is_integer(i), for: Blah do
  def empty(), do: 0
  defmacro succ(i), do: quote(do: unquote(i)+1) # Macro's get inlined into the protocol itself
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

defmodule MyStruct do
  defstruct a: 42
end

defimplEx MineOlStruct, %MyStruct{}, for: Blah do
  def empty(), do: %MyStruct{a: 0}
  def succ(s), do: %{s | a: s.a+1}
  def add(s, b), do: %{s | a: s.a+b}
  def map(s, f), do: %{s | a: f.(s.a)}
end
```

### `resolveProtocolEx/2`

`resolveProtocolEx/2` allows to dynamic consolidation (or if you do not wish to use the compiler).  It takes the protocol module name first, then a list of the unique names to consolidate.  If there is more than one implementation that can match a given value then they are used in the order of definition here.

#### Example

```elixir
ProtocolEx.resolveProtocolEx(Blah, [
  Integer,
  TaggedTuple.Vwoop,
  MineOlStruct,
])
```

This can be called *again* at runtime if so wished, it allows you rebuild the protocol consolidation module to remove or add implementations such as for dynamic plugins.

### Protocol Usage

To use your protocol you just call the specific functions on the module, for the above examples then all of these will work:

```elixir
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
```

It can of course be useful to call an implementation directly as well:

```elixir
0                  = Blah.Integer.empty()
{Vwoop, 0}         = Blah.TaggedTuple.Vwoop.empty()
%MyStruct{a: 0}    = Blah.MineOlStruct.empty()
```
