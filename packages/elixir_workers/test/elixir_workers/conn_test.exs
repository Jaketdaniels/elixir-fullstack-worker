defmodule ElixirWorkers.ConnTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.Conn

  defp new_conn(overrides \\ %{}) do
    raw =
      Map.merge(
        %{
          "method" => "GET",
          "url" => "/",
          "headers" => %{},
          "body" => "",
          "env" => %{},
          "cf" => %{},
          "_state" => %{}
        },
        overrides
      )

    Conn.new(raw)
  end

  describe "new/1" do
    test "builds conn from raw request" do
      conn = new_conn(%{"url" => "/posts/42?page=2", "method" => "POST"})
      assert conn["method"] == "POST"
      assert conn["path"] == "/posts/42"
      assert conn["query_string"] == "page=2"
      assert conn["query_params"] == %{"page" => "2"}
      assert conn["path_segments"] == ["posts", "42"]
    end

    test "defaults to GET and root path" do
      conn = Conn.new(%{})
      assert conn["method"] == "GET"
      assert conn["path"] == "/"
    end

    test "initializes empty needs and effects" do
      conn = new_conn()
      assert conn["_needs"] == []
      assert conn["_effects"] == []
    end

    test "initializes response fields as nil" do
      conn = new_conn()
      assert conn["status"] == nil
      assert conn["resp_body"] == nil
      assert conn["halted"] == false
    end
  end

  describe "html/3" do
    test "sets HTML response" do
      conn = new_conn() |> Conn.html(200, "<h1>Hello</h1>")
      assert conn["status"] == 200
      assert conn["resp_body"] == "<h1>Hello</h1>"
      assert conn["resp_headers"]["content-type"] == "text/html; charset=utf-8"
    end
  end

  describe "json/3" do
    test "sets JSON response" do
      conn = new_conn() |> Conn.json(200, %{"ok" => true})
      assert conn["status"] == 200
      assert conn["resp_headers"]["content-type"] == "application/json"
      decoded = ElixirWorkers.JSON.decode(conn["resp_body"])
      assert decoded == %{"ok" => true}
    end

    test "sets error JSON response" do
      conn = new_conn() |> Conn.json(404, %{"error" => "not_found"})
      assert conn["status"] == 404
    end
  end

  describe "text/3" do
    test "sets plain text response" do
      conn = new_conn() |> Conn.text(200, "hello")
      assert conn["status"] == 200
      assert conn["resp_body"] == "hello"
      assert conn["resp_headers"]["content-type"] == "text/plain; charset=utf-8"
    end
  end

  describe "redirect/2" do
    test "sets redirect response" do
      conn = new_conn() |> Conn.redirect("/login")
      assert conn["status"] == 302
      assert conn["resp_headers"]["location"] == "/login"
      assert conn["resp_body"] == ""
    end

    test "supports custom status code" do
      conn = new_conn() |> Conn.redirect("/home", 301)
      assert conn["status"] == 301
    end
  end

  describe "put_resp_header/3" do
    test "adds a response header" do
      conn = new_conn() |> Conn.put_resp_header("x-custom", "value")
      assert conn["resp_headers"]["x-custom"] == "value"
    end

    test "overwrites existing header" do
      conn =
        new_conn()
        |> Conn.put_resp_header("x-test", "old")
        |> Conn.put_resp_header("x-test", "new")

      assert conn["resp_headers"]["x-test"] == "new"
    end
  end

  describe "needs and effects" do
    test "add_need appends a need" do
      conn = new_conn() |> Conn.add_need(%{"type" => "kv_get", "id" => "test"})
      assert length(conn["_needs"]) == 1
    end

    test "add_effect appends an effect" do
      conn = new_conn() |> Conn.add_effect(%{"type" => "kv_put"})
      assert length(conn["_effects"]) == 1
    end

    test "needs_bindings? returns true with needs" do
      conn = new_conn() |> Conn.add_need(%{"type" => "test"})
      assert Conn.needs_bindings?(conn) == true
    end

    test "needs_bindings? returns false without needs" do
      assert Conn.needs_bindings?(new_conn()) == false
    end
  end

  describe "state" do
    test "put_state and get_state" do
      conn = new_conn() |> Conn.put_state("user_id", "42")
      assert Conn.get_state(conn, "user_id") == "42"
    end

    test "get_state returns default for missing key" do
      assert Conn.get_state(new_conn(), "missing", "default") == "default"
    end
  end

  describe "to_response/1" do
    test "returns needs response when bindings needed" do
      conn = new_conn() |> Conn.add_need(%{"type" => "kv_get", "id" => "t1"})
      resp = Conn.to_response(conn)
      assert is_list(resp["_needs"])
      assert length(resp["_needs"]) == 1
      assert resp["_state"] != nil
    end

    test "returns HTTP response when no needs" do
      conn = new_conn() |> Conn.html(200, "ok")
      resp = Conn.to_response(conn)
      assert resp["status"] == 200
      assert resp["body"] == "ok"
      assert resp["headers"]["content-type"] == "text/html; charset=utf-8"
    end

    test "includes effects in response" do
      conn =
        new_conn()
        |> Conn.html(200, "ok")
        |> Conn.add_effect(%{"type" => "kv_put", "key" => "test"})

      resp = Conn.to_response(conn)
      assert is_list(resp["_effects"])
      assert length(resp["_effects"]) == 1
    end

    test "omits effects when empty" do
      conn = new_conn() |> Conn.html(200, "ok")
      resp = Conn.to_response(conn)
      refute Map.has_key?(resp, "_effects")
    end
  end
end
