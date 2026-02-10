defmodule ElixirWorkers.URLTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.URL

  describe "parse_path/1" do
    test "parses path without query string" do
      assert URL.parse_path("/posts/42") == %{"path" => "/posts/42", "query_string" => ""}
    end

    test "parses path with query string" do
      result = URL.parse_path("/search?q=hello&page=2")
      assert result["path"] == "/search"
      assert result["query_string"] == "q=hello&page=2"
    end

    test "parses root path" do
      assert URL.parse_path("/") == %{"path" => "/", "query_string" => ""}
    end

    test "parses path with empty query string" do
      assert URL.parse_path("/test?") == %{"path" => "/test", "query_string" => ""}
    end
  end

  describe "split_path/1" do
    test "splits root to empty list" do
      assert URL.split_path("/") == []
    end

    test "splits single segment" do
      assert URL.split_path("/posts") == ["posts"]
    end

    test "splits multiple segments" do
      assert URL.split_path("/api/users/42") == ["api", "users", "42"]
    end

    test "handles trailing slash" do
      assert URL.split_path("/posts/") == ["posts"]
    end

    test "handles double slashes" do
      assert URL.split_path("/a//b") == ["a", "b"]
    end
  end

  describe "decode_query/1" do
    test "empty string returns empty map" do
      assert URL.decode_query("") == %{}
    end

    test "decodes single pair" do
      assert URL.decode_query("a=1") == %{"a" => "1"}
    end

    test "decodes multiple pairs" do
      result = URL.decode_query("a=1&b=2")
      assert result == %{"a" => "1", "b" => "2"}
    end

    test "decodes plus as space" do
      assert URL.decode_query("q=hello+world") == %{"q" => "hello world"}
    end

    test "decodes percent-encoded values" do
      assert URL.decode_query("path=%2Fhome") == %{"path" => "/home"}
    end

    test "decodes key without value" do
      assert URL.decode_query("flag") == %{"flag" => ""}
    end
  end

  describe "percent_decode/1" do
    test "decodes simple percent encoding" do
      assert URL.percent_decode("hello%20world") == "hello world"
    end

    test "decodes slash" do
      assert URL.percent_decode("%2F") == "/"
    end

    test "decodes plus as space" do
      assert URL.percent_decode("hello+world") == "hello world"
    end

    test "passes through plain text" do
      assert URL.percent_decode("hello") == "hello"
    end
  end

  describe "match_path/2" do
    test "matches exact path" do
      assert URL.match_path(["posts"], ["posts"]) == {:ok, %{}}
    end

    test "matches with parameters" do
      assert URL.match_path(["posts", "42"], ["posts", ":id"]) == {:ok, %{"id" => "42"}}
    end

    test "matches multiple parameters" do
      result =
        URL.match_path(["users", "5", "posts", "10"], ["users", ":user_id", "posts", ":post_id"])

      assert result == {:ok, %{"user_id" => "5", "post_id" => "10"}}
    end

    test "returns no_match for wrong segment" do
      assert URL.match_path(["posts"], ["users"]) == :no_match
    end

    test "returns no_match for different lengths" do
      assert URL.match_path(["posts", "42", "extra"], ["posts", ":id"]) == :no_match
    end

    test "matches wildcard" do
      {:ok, params} = URL.match_path(["static", "css", "app.css"], ["static", "*"])
      assert params["*"] == "css/app.css"
    end

    test "matches empty path segments" do
      assert URL.match_path([], []) == {:ok, %{}}
    end
  end
end
