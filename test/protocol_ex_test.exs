defmodule ProtocolExTest do
  use ExUnit.Case, async: true
  doctest ProtocolEx

  test "the truth" do
    assert 0 === Blah.Integer.empty()

    assert 0 === Blah.empty(42)
    assert {Vwoop, 0} === Blah.empty({Vwoop, 42})
    assert %MyStruct{a: 0} === Blah.empty(%MyStruct{})

    assert 43 === Blah.succ(42)
    assert {Vwoop, 43} === Blah.succ({Vwoop, 42})
    assert %MyStruct{a: 43} === Blah.succ(%MyStruct{a: 42})

    assert 43 === Blah.add(42, 1)
    assert {Vwoop, 43} === Blah.add({Vwoop, 42}, 1)
    assert %MyStruct{a: 43} === Blah.add(%MyStruct{a: 42}, 1)
  end


  use ExUnitProperties

  property "Integers in the Blah protocol" do
    check all(i <- integer(), j <- integer()) do
      assert 0 === Blah.empty(i)
      assert (i + 1) === Blah.succ(i)
      assert (i + j) === Blah.add(i, j)
    end
  end
end
