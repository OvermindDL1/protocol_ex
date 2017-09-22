defmodule ProtocolExTest do
  use ExUnit.Case, async: true
  doctest ProtocolEx

  test "the truth" do
    assert 0 === Testering.Blah.Integer.empty(42)

    assert 0 === Testering.Blah.empty(42)
    assert {Vwoop, 0} === Testering.Blah.empty({Vwoop, 42})
    assert %MyStruct{a: 0} === Testering.Blah.empty(%MyStruct{})

    assert 43 === Testering.Blah.succ(42)
    assert {Vwoop, 43} === Testering.Blah.succ({Vwoop, 42})
    assert %MyStruct{a: 43} === Testering.Blah.succ(%MyStruct{a: 42})

    assert 43 === Testering.Blah.add(42, 1)
    assert {Vwoop, 43} === Testering.Blah.add({Vwoop, 42}, 1)
    assert %MyStruct{a: 43} === Testering.Blah.add(%MyStruct{a: 42}, 1)
  end


  use ExUnitProperties

  property "Integers in the Blah protocol" do
    check all(i <- integer(), j <- integer()) do
      assert 0 === Testering.Blah.empty(i)
      assert (i + 1) === Testering.Blah.succ(i)
      assert (i + j) === Testering.Blah.add(i, j)
    end
  end
end
