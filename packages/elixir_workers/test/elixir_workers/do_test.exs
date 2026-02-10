defmodule ElixirWorkers.DOTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.{Conn, DO}

  defp new_conn(bindings \\ %{}) do
    Conn.new(%{
      "method" => "GET",
      "url" => "/",
      "headers" => %{},
      "body" => "",
      "env" => %{},
      "bindings" => bindings,
      "_state" => %{}
    })
  end

  defp need_id(namespace, name, method, args) do
    "do:" <>
      namespace <>
      ":" <> name <> ":" <> method <> ":" <> :erlang.integer_to_binary(:erlang.phash2(args))
  end

  describe "call/5 - pass 1" do
    test "registers a do_rpc need" do
      {conn, result} =
        DO.call(new_conn(), "CHAT_ROOMS", "dm:u1:u2", "getConversation", ["u1", "u2", 50])

      assert result == nil
      assert length(conn["_needs"]) == 1
      [need] = conn["_needs"]
      assert need["type"] == "do_rpc"
      assert need["ns"] == "CHAT_ROOMS"
      assert need["name"] == "dm:u1:u2"
      assert need["method"] == "getConversation"
      assert need["args"] == ["u1", "u2", 50]
    end
  end

  describe "call/5 - pass 2" do
    test "returns value payload from wrapped binding" do
      id = need_id("CHAT_ROOMS", "dm:u1:u2", "getConversation", ["u1", "u2", 50])

      bindings = %{
        id => %{
          "ok" => true,
          "value" => %{"messages" => [%{"id" => 1}], "typing" => false}
        }
      }

      {conn, value} =
        DO.call(new_conn(bindings), "CHAT_ROOMS", "dm:u1:u2", "getConversation", ["u1", "u2", 50])

      assert value["typing"] == false
      assert value["messages"] == [%{"id" => 1}]
      assert conn["_needs"] == []
    end

    test "returns error map when wrapped binding reports failure" do
      id = need_id("CHAT_ROOMS", "dm:u1:u2", "sendMessage", [%{"from_id" => "u1"}])
      bindings = %{id => %{"ok" => false, "error" => "rpc failed"}}

      {_, value} =
        DO.call(new_conn(bindings), "CHAT_ROOMS", "dm:u1:u2", "sendMessage", [
          %{"from_id" => "u1"}
        ])

      assert value == %{"error" => "rpc failed"}
    end

    test "returns raw binding value for backward compatibility" do
      id = need_id("CHAT_STATS", "global", "getTotals", [])
      bindings = %{id => %{"messages" => 42}}

      {_, value} = DO.call(new_conn(bindings), "CHAT_STATS", "global", "getTotals")
      assert value["messages"] == 42
    end
  end

  describe "cast/5" do
    test "adds do_rpc effect with args" do
      conn = DO.cast(new_conn(), "CHAT_STATS", "global", "incrementMessages", [1])
      assert length(conn["_effects"]) == 1
      [effect] = conn["_effects"]
      assert effect["type"] == "do_rpc"
      assert effect["ns"] == "CHAT_STATS"
      assert effect["name"] == "global"
      assert effect["method"] == "incrementMessages"
      assert effect["args"] == [1]
    end

    test "omits args when empty" do
      conn = DO.cast(new_conn(), "CHAT_STATS", "global", "getTotals")
      [effect] = conn["_effects"]
      refute Map.has_key?(effect, "args")
    end
  end
end
