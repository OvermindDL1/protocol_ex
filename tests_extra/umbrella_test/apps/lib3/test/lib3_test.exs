defmodule Lib3Test do
  use ExUnit.Case
  doctest Lib3

  test "greets the world" do
    assert Lib3.hello() == :world
  end
end
