defmodule ElixirWorkers.BodyTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.Body

  describe "parse/2" do
    test "parses JSON body" do
      result = Body.parse(~s({"key":"value"}), "application/json")
      assert result == %{"key" => "value"}
    end

    test "parses URL-encoded body" do
      result = Body.parse("name=Alice&age=30", "application/x-www-form-urlencoded")
      assert result == %{"name" => "Alice", "age" => "30"}
    end

    test "returns raw body for unknown content type" do
      assert Body.parse("raw data", "text/plain") == "raw data"
    end

    test "returns raw body for nil content type" do
      assert Body.parse("data", nil) == "data"
    end

    test "handles empty JSON body" do
      assert Body.parse("", "application/json") == %{}
    end

    test "handles JSON with charset suffix" do
      result = Body.parse(~s({"a":1}), "application/json; charset=utf-8")
      assert result == %{"a" => 1}
    end
  end

  describe "parse_urlencoded/1" do
    test "decodes form data" do
      assert Body.parse_urlencoded("x=1&y=2") == %{"x" => "1", "y" => "2"}
    end

    test "decodes plus-encoded spaces" do
      assert Body.parse_urlencoded("q=hello+world") == %{"q" => "hello world"}
    end
  end

  describe "parse_json/1" do
    test "decodes JSON" do
      assert Body.parse_json(~s({"ok":true})) == %{"ok" => true}
    end

    test "returns empty map for empty string" do
      assert Body.parse_json("") == %{}
    end

    test "returns empty map for nil" do
      assert Body.parse_json(nil) == %{}
    end
  end
end
