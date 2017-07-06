defmodule ProtocolExTest do
  use ExUnit.Case
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
end
