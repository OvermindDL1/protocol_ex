defmodule ConsolidateTestTest do
  use ExUnit.Case

  alias SubModule.MyStruct

  test "Blah" do
    assert 0                  = Blah.empty(42)
    assert {Vwoop, 0}         = Blah.empty({Vwoop, 42})
    assert %MyStruct{a: 0}    = Blah.empty(%MyStruct{a: 42})

    assert 43                 = Blah.succ(42)
    assert {Vwoop, 43}        = Blah.succ({Vwoop, 42})
    assert %MyStruct{a: 43}   = Blah.succ(%MyStruct{a: 42})

    assert 47                 = Blah.add(42, 5)
    assert {Vwoop, 47}        = Blah.add({Vwoop, 42}, 5)
    assert %MyStruct{a: 47}   = Blah.add(%MyStruct{a: 42}, 5)

    assert "Integer: 42"      = Blah.a_fallback(42)
    assert "{Vwoop, 42}"      = Blah.a_fallback({Vwoop, 42})
    assert "%SubModule.MyStruct{a: 42}" = Blah.a_fallback(%MyStruct{a: 42})

    assert 43                 = Blah.map(42, &(&1+1))
    assert {Vwoop, 43}        = Blah.map({Vwoop, 42}, &(&1+1))
    assert %MyStruct{a: 43}   = Blah.map(%MyStruct{a: 42}, &(&1+1))

    alias Bloop.Bloop
    assert {:integer, 42}     = Bloop.get(42)
    assert {:integer, 42}     = Bloop.get_with_fallback(42)
    assert {:fallback, 6.28}  = Bloop.get_with_fallback(6.28)

    #assert_raise ProtocolEx.UnimplementedProtocolEx, fn ->
    assert_raise FunctionClauseError, fn ->
      Bloop.get(6.28)
    end
  end
end
