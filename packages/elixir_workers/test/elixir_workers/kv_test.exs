defmodule ElixirWorkers.KVTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.{Conn, KV}

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

  describe "get/3 - pass 1 (no bindings)" do
    test "registers a kv_get need" do
      {conn, value} = KV.get(new_conn(), "LOCATIONS", "user:42")
      assert value == nil
      assert length(conn["_needs"]) == 1
      [need] = conn["_needs"]
      assert need["type"] == "kv_get"
      assert need["ns"] == "LOCATIONS"
      assert need["key"] == "user:42"
    end
  end

  describe "get/3 - pass 2 (with bindings)" do
    test "returns value from bindings" do
      bindings = %{"kv_get:LOCATIONS:user:42" => ~s({"lat":1,"lng":2})}
      {conn, value} = KV.get(new_conn(bindings), "LOCATIONS", "user:42")
      assert value == ~s({"lat":1,"lng":2})
      assert conn["_needs"] == []
    end
  end

  describe "get_with_metadata/3" do
    test "registers kv_get_meta need on pass 1" do
      {_conn, value} = KV.get_with_metadata(new_conn(), "LOCATIONS", "user:1")
      assert value == nil
    end

    test "returns result on pass 2" do
      result = %{"value" => "data", "metadata" => %{"ts" => "123"}}
      bindings = %{"kv_get_meta:LOCATIONS:user:1" => result}
      {_conn, value} = KV.get_with_metadata(new_conn(bindings), "LOCATIONS", "user:1")
      assert value == result
    end
  end

  describe "list/3" do
    test "registers kv_list need on pass 1" do
      {conn, value} = KV.list(new_conn(), "LOCATIONS", %{"prefix" => "user:"})
      assert value == nil
      assert length(conn["_needs"]) == 1
      [need] = conn["_needs"]
      assert need["type"] == "kv_list"
      assert need["prefix"] == "user:"
    end
  end

  describe "put/5" do
    test "adds kv_put effect" do
      conn = KV.put(new_conn(), "LOCATIONS", "user:42", "data")
      assert length(conn["_effects"]) == 1
      [effect] = conn["_effects"]
      assert effect["type"] == "kv_put"
      assert effect["key"] == "user:42"
      assert effect["value"] == "data"
    end

    test "includes TTL option" do
      conn = KV.put(new_conn(), "LOCATIONS", "k", "v", %{"expiration_ttl" => 300})
      [effect] = conn["_effects"]
      assert effect["expiration_ttl"] == 300
    end

    test "includes metadata option" do
      meta = %{"ts" => "now"}
      conn = KV.put(new_conn(), "LOCATIONS", "k", "v", %{"metadata" => meta})
      [effect] = conn["_effects"]
      assert effect["metadata"] == meta
    end
  end

  describe "delete/3" do
    test "adds kv_delete effect" do
      conn = KV.delete(new_conn(), "LOCATIONS", "user:42")
      [effect] = conn["_effects"]
      assert effect["type"] == "kv_delete"
      assert effect["key"] == "user:42"
    end
  end
end
