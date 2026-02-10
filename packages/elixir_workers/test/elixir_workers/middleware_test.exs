defmodule ElixirWorkers.MiddlewareTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.{Conn, Middleware}

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

  describe "security_headers/1" do
    test "adds security headers" do
      conn = new_conn() |> Middleware.security_headers()
      assert conn["resp_headers"]["x-content-type-options"] == "nosniff"
      assert conn["resp_headers"]["x-frame-options"] == "DENY"
      assert conn["resp_headers"]["strict-transport-security"] =~ "max-age="
    end
  end

  describe "parse_body/1" do
    test "parses JSON body" do
      conn =
        new_conn(%{"body" => ~s({"a":1}), "headers" => %{"content-type" => "application/json"}})

      conn = Middleware.parse_body(conn)
      assert conn["parsed_body"] == %{"a" => 1}
    end

    test "parses form body" do
      conn =
        new_conn(%{
          "body" => "x=1",
          "headers" => %{"content-type" => "application/x-www-form-urlencoded"}
        })

      conn = Middleware.parse_body(conn)
      assert conn["parsed_body"] == %{"x" => "1"}
    end

    test "returns raw body for unknown content type" do
      conn = new_conn(%{"body" => "raw", "headers" => %{"content-type" => "text/plain"}})
      conn = Middleware.parse_body(conn)
      assert conn["parsed_body"] == "raw"
    end
  end

  describe "cors/2" do
    test "adds CORS headers" do
      conn = new_conn() |> Middleware.cors()
      assert conn["resp_headers"]["access-control-allow-origin"] == "*"
      assert conn["resp_headers"]["access-control-allow-methods"] =~ "GET"
    end

    test "custom origin" do
      conn = new_conn() |> Middleware.cors(%{"origin" => "https://example.com"})
      assert conn["resp_headers"]["access-control-allow-origin"] == "https://example.com"
    end

    test "handles OPTIONS preflight" do
      conn = new_conn(%{"method" => "OPTIONS"}) |> Middleware.cors()
      assert conn["halted"] == true
      assert conn["status"] == 204
      assert conn["resp_headers"]["access-control-max-age"] == "86400"
    end

    test "does not halt for non-OPTIONS" do
      conn = new_conn(%{"method" => "GET"}) |> Middleware.cors()
      assert conn["halted"] == false
    end
  end

  describe "run/2" do
    test "runs middleware chain" do
      conn =
        new_conn()
        |> Middleware.run([
          &Middleware.security_headers/1,
          &Middleware.parse_body/1
        ])

      assert conn["resp_headers"]["x-content-type-options"] == "nosniff"
      assert Map.has_key?(conn, "parsed_body")
    end

    test "stops on halted conn" do
      halter = fn conn -> conn |> Map.put("halted", true) end
      tracker = fn conn -> Conn.put_state(conn, "ran", true) end

      conn = new_conn() |> Middleware.run([halter, tracker])
      assert conn["halted"] == true
      assert Conn.get_state(conn, "ran") == nil
    end

    test "handles empty middleware list" do
      conn = new_conn()
      assert Middleware.run(conn, []) == conn
    end
  end
end
