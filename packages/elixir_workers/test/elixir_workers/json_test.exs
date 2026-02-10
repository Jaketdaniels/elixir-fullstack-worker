defmodule ElixirWorkers.JSONTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.JSON

  describe "decode/1" do
    test "decodes strings" do
      assert JSON.decode(~s("hello")) == "hello"
    end

    test "decodes escaped characters in strings" do
      assert JSON.decode(~s("line1\\nline2")) == "line1\nline2"
      assert JSON.decode(~s("tab\\there")) == "tab\there"
      assert JSON.decode(~s("quote\\"here")) == "quote\"here"
      assert JSON.decode(~s("back\\\\slash")) == "back\\slash"
    end

    test "decodes unicode escapes" do
      assert JSON.decode(~s("\\u0041")) == "A"
    end

    test "decodes integers" do
      assert JSON.decode("42") == 42
      assert JSON.decode("-7") == -7
      assert JSON.decode("0") == 0
    end

    test "decodes floats" do
      assert JSON.decode("3.14") == 3.14
      assert JSON.decode("-0.5") == -0.5
    end

    test "decodes scientific notation" do
      assert JSON.decode("1.0e2") == 1.0e2
      assert JSON.decode("1.5E-3") == 1.5e-3
    end

    test "decodes booleans" do
      assert JSON.decode("true") == true
      assert JSON.decode("false") == false
    end

    test "decodes null" do
      assert JSON.decode("null") == nil
    end

    test "decodes empty object" do
      assert JSON.decode("{}") == %{}
    end

    test "decodes object with values" do
      assert JSON.decode(~s({"a":1,"b":"two"})) == %{"a" => 1, "b" => "two"}
    end

    test "decodes nested objects" do
      assert JSON.decode(~s({"x":{"y":true}})) == %{"x" => %{"y" => true}}
    end

    test "decodes empty array" do
      assert JSON.decode("[]") == []
    end

    test "decodes array with values" do
      assert JSON.decode("[1,2,3]") == [1, 2, 3]
    end

    test "decodes mixed array" do
      assert JSON.decode(~s([1,"two",null,true])) == [1, "two", nil, true]
    end

    test "decodes with whitespace" do
      assert JSON.decode("  { \"a\" : 1 }  ") == %{"a" => 1}
    end
  end

  describe "encode/1" do
    test "encodes nil as null" do
      assert JSON.encode(nil) == "null"
    end

    test "encodes booleans" do
      assert JSON.encode(true) == "true"
      assert JSON.encode(false) == "false"
    end

    test "encodes integers" do
      assert JSON.encode(42) == "42"
      assert JSON.encode(-7) == "-7"
    end

    test "encodes strings" do
      assert JSON.encode("hello") == ~s("hello")
    end

    test "encodes strings with special characters" do
      encoded = JSON.encode("line\nnew")
      assert encoded == ~s("line\\nnew")
    end

    test "encodes strings with quotes" do
      encoded = JSON.encode("say \"hi\"")
      assert encoded == ~s("say \\"hi\\"")
    end

    test "encodes empty map" do
      assert JSON.encode(%{}) == "{}"
    end

    test "encodes map" do
      result = JSON.encode(%{"a" => 1})
      assert result == ~s({"a":1}) or result == ~s({"a": 1})
    end

    test "encodes empty list" do
      assert JSON.encode([]) == "[]"
    end

    test "encodes list" do
      assert JSON.encode([1, 2, 3]) == "[1,2,3]"
    end

    test "encodes atoms as strings" do
      encoded = JSON.encode(:hello)
      assert encoded == ~s("hello")
    end

    test "roundtrip encode/decode" do
      data = %{"name" => "test", "count" => 42, "active" => true, "tags" => ["a", "b"]}
      assert JSON.decode(JSON.encode(data)) == data
    end
  end
end
