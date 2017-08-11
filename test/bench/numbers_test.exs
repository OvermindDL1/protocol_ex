import ProtocolEx

defmodule ProtocolEx.MyNumbers do
  defprotocolEx Basic do
    def add(a, b)
    def mult(a, b)
  end

  defprotocolEx Coerce do
    def coerce({l, r})
    def coerce(l, r), do: coerce({l, r})
  end
end

defmodule ProtocolEx.MyNumbers.Impls do
  defimplEx Decimal, %Decimal{}, for: ProtocolEx.MyNumbers.Basic, inline: [add: 2, mult: 2] do
    def add(%Decimal{}=a, b), do: Decimal.add(a, b)
    def mult(%Decimal{}=a, b), do: Decimal.mult(a, b)
  end

  # Do not inline cavalier, it changes the function scope to the protocol,
  # so local calls will not work unless they are to the protocol, nor alias or anything not in the function scope.
  defimplEx Integer, i when is_integer(i), for: ProtocolEx.MyNumbers.Basic, inline: [add: 2, mult: 2] do
    def add(a, b) when is_integer(a), do: a + b
    def mult(a, b) when is_integer(b), do: a * b
  end

  defimplEx Float, f when is_float(f), for: ProtocolEx.MyNumbers.Basic, inline: [add: 2, mult: 2] do
    def add(a, b) when is_float(a), do: a + b
    def mult(a, b) when is_float(a), do: a * b
  end

  defimplEx MyDecimal, {MyDecimal, s, c, e}, for: ProtocolEx.MyNumbers.Basic, inline: [add: 2, mult: 2] do
    def add({MyDecimal, _s0, :sNaN, _e0}, {MyDecimal, _s1, _c1, _e1}), do: throw :error
    def add({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :sNaN, _e1}), do: throw :error
    def add({MyDecimal, _s0, :qNaN, _e0} = d0, {MyDecimal, _s1, _c1, _e1}), do: d0
    def add({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :qNaN, _e1} = d1), do: d1
    def add({MyDecimal, s0, :inf, e0} = d0, {MyDecimal, s0, :inf, e1} = d1), do: if(e0 > e1, do: d0, else: d1)
    def add({MyDecimal, _s0, :inf, _e0}, {MyDecimal, _s1, :inf, _e1}), do: throw :error
    def add({MyDecimal, _s0, :inf, _e0} = d0, {MyDecimal, _s1, _c1, _e1}), do: d0
    def add({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :inf, _e1} = d1), do: d1
    def add({MyDecimal, s0, c0, e0}, {MyDecimal, s1, c1, e1}) do
      {c0, c1} =
        cond do
          e0 === e1 -> {c0, c1}
          e0 > e1 -> {c0 * ProtocolEx.MyNumbers.Basic.MyDecimal.pow10(e0 - e1), c1}
          true -> {c0, c1 * ProtocolEx.MyNumbers.Basic.MyDecimal.pow10(e1 - e0)}
        end
      c = s0 * c0 + s1 * c1
      e = Kernel.min(e0, e1)
      s =
        cond do
          c > 0 -> 1
          c < 0 -> -1
          s0 == -1 and s1 == -1 -> -1
          # s0 != s1 and get_context().rounding == :floor -> -1
          true -> 1
        end
      {s, Kernel.abs(c), e}
    end

    def mult({MyDecimal, _s0, :sNaN, _e0}, {MyDecimal, _s1, _c1, _e1}), do: throw :error
    def mult({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :sNaN, _e1}), do: throw :error
    def mult({MyDecimal, _s0, :qNaN, _e0}, {MyDecimal, _s1, _c1, _e1}), do: throw :error
    def mult({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :qNaN, _e1}), do: throw :error
    def mult({MyDecimal, _s0, 0, _e0}, {MyDecimal, _s1, :inf, _e1}), do: throw :error
    def mult({MyDecimal, _s0, :inf, _e0}, {MyDecimal, _s1, 0, _e1}), do: throw :error
    def mult({MyDecimal, s0, :inf, e0}, {MyDecimal, s1, _, e1}) do
      s = s0 * s1
      {s, :inf, e0+e1}
    end
    def mult({MyDecimal, s0, _, e0}, {MyDecimal, s1, :inf, e1}) do
      s = s0 * s1
      {s, :inf, e0+e1}
    end
    def mult({MyDecimal, s0, c0, e0}, {MyDecimal, s1, c1, e1}) do
      s = s0 * s1
      {s, c0 * c1, e0 + e1}
    end

    _pow10_max = Enum.reduce 0..104, 1, fn int, acc ->
      def pow10(unquote(int)), do: unquote(acc)
      def base10?(unquote(acc)), do: true
      acc * 10
    end
    def pow10(num) when num > 104, do: pow10(104) * pow10(num - 104)
  end

  # Coerce
  defimplEx IntegerFloat, {l, r} when (is_integer(l) and is_float(r)) or (is_integer(r) and is_float(l)), for: ProtocolEx.MyNumbers.Coerce, inline: [coerce: 1] do
    def coerce({l, r}) when (is_integer(l) and is_float(r)) or (is_integer(r) and is_float(l)), do: {0.0+l, 0.0+r}
  end
  defimplEx Integer, {l, r} when is_integer(l) and is_integer(r), for: ProtocolEx.MyNumbers.Coerce, inline: [coerce: 1] do
    def coerce({l, r}) when is_integer(l) and is_integer(r), do: {l, r}
  end
  defimplEx Float, {l, r} when is_float(l) and is_float(r), for: ProtocolEx.MyNumbers.Coerce, inline: [coerce: 1] do
    def coerce({l, r}) when is_float(l) and is_float(r), do: {l, r}
  end
  defimplEx Decimal,{%Decimal{}, %Decimal{}}, for: ProtocolEx.MyNumbers.Coerce, inline: [coerce: 1] do
    def coerce({%Decimal{}, %Decimal{}} = result), do: result
  end
  defimplEx MyDecimal,{{MyDecimal, _, _, _}, {MyDecimal, _, _, _}}, for: ProtocolEx.MyNumbers.Coerce, inline: [coerce: 1] do
    def coerce({{MyDecimal, _, _, _}, {MyDecimal, _, _, _}} = result), do: result
  end
end

defmodule ProtocolEx.MyNumbers.Resolved do
  resolveProtocolEx(ProtocolEx.MyNumbers.Basic, [
    Integer,
    Float,
    Decimal,
    MyDecimal,
  ])

  resolveProtocolEx(ProtocolEx.MyNumbers.Coerce, [
    Integer,
    Float,
    Decimal,
    MyDecimal,
    IntegerFloat,
  ])
end



defmodule ProtocolEx.Bench.NumbersTest do
  use ExUnit.Case, async: false
  @moduletag :bench
  @moduletag timeout: 300000

  test "Numbers - Bench" do
    inputs = %{
      "Integers"    => {7, 11},
      "Floats"      => {6.28, 4.24},
      "Decimal"     => {Decimal.div(Decimal.new(8), Decimal.new(3)), Decimal.new(2)},
      "MyDecimal"   => {{MyDecimal, 1, 2666666666666666666666666667, -27}, {MyDecimal, 1, 8, 0}}
    }

    bench = %{
      "MyNumbers"   => fn {l, r} -> {l, r} = ProtocolEx.MyNumbers.Coerce.coerce(l, r); ProtocolEx.MyNumbers.Basic.add(l, r) end,
      "MyNumbers - sans coerce"   => fn {l, r} ->ProtocolEx.MyNumbers.Basic.add(l, r) end,
      "Numbers"     => fn {l, r} -> Numbers.add(l, r) end,
      "Numbers - sans coerce"     => fn {l, r} -> Numbers.Protocols.Addition.add(l, r) end,
      "Numbers - my coerce"     => fn {l, r} -> {l, r} = ProtocolEx.MyNumbers.Coerce.coerce(l, r); Numbers.Protocols.Addition.add(l, r) end,
    }

    Benchee.run(bench, inputs: inputs, time: 3, warmup: 3, print: [fast_warning: false])
  end

end
