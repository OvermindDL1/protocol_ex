defmodule Lib1Test do
  use ExUnit.Case
  doctest Lib1

  test "greets the world" do
    assert Lib1.hello() == :world
  end
end
