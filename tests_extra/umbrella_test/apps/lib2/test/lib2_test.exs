defmodule Lib2Test do
  use ExUnit.Case
  doctest Lib2

  test "greets the world" do
    assert Lib2.hello() == :world
  end
end
