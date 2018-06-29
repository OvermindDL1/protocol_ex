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

  #test "Failure" do
  #  assert 42 == Blah.add("42", "16")
  #end

  test "Aliasing" do
    alias Mod1.Mod11.Mod111
    assert %Mod111{a: 0} = ModProto.blah(%Mod111{a: 1})
  end

  test "Defaults" do
    assert 2 = Defaults.succ(1)
    assert 3 = Defaults.succ(1, 2)
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
