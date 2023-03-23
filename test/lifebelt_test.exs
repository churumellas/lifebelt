defmodule LifebeltTest do
  use ExUnit.Case
  doctest Lifebelt

  test "greets the world" do
    assert Lifebelt.hello() == :world
  end
end
