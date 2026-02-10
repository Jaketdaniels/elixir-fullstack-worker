defmodule ElixirWorkers.D1Test do
  use ExUnit.Case, async: true

  alias ElixirWorkers.{Conn, D1}

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

  describe "query/4 - pass 1" do
    test "registers a d1_query need" do
      {conn, result} = D1.query(new_conn(), "DB", "SELECT * FROM users")
      assert result == nil
      assert length(conn["_needs"]) == 1
      [need] = conn["_needs"]
      assert need["type"] == "d1_query"
      assert need["db"] == "DB"
      assert need["sql"] == "SELECT * FROM users"
    end

    test "includes params when provided" do
      {conn, _} = D1.query(new_conn(), "DB", "SELECT * FROM users WHERE id = ?", ["42"])
      [need] = conn["_needs"]
      assert need["params"] == ["42"]
    end
  end

  describe "query/4 - pass 2" do
    test "returns rows from bindings (map result)" do
      rows = [%{"id" => "1", "name" => "Alice"}]
      need_id = "d1:DB:SELECT * FROM users:"
      bindings = %{need_id => %{"rows" => rows}}
      {conn, result} = D1.query(new_conn(bindings), "DB", "SELECT * FROM users")
      assert result == rows
      assert conn["_needs"] == []
    end

    test "returns rows from bindings (list result)" do
      rows = [%{"id" => "1"}]
      need_id = "d1:DB:SELECT 1:"
      bindings = %{need_id => rows}
      {_conn, result} = D1.query(new_conn(bindings), "DB", "SELECT 1")
      assert result == rows
    end
  end

  describe "query_one/4" do
    test "returns nil on pass 1" do
      {_conn, result} = D1.query_one(new_conn(), "DB", "SELECT * FROM users WHERE id = ?", ["1"])
      assert result == nil
    end

    test "returns first row on pass 2" do
      rows = [%{"id" => "1", "name" => "Alice"}, %{"id" => "2", "name" => "Bob"}]
      need_id = "d1:DB:SELECT * FROM users:"
      bindings = %{need_id => %{"rows" => rows}}
      {_conn, result} = D1.query_one(new_conn(bindings), "DB", "SELECT * FROM users")
      assert result == %{"id" => "1", "name" => "Alice"}
    end

    test "returns nil for empty results on pass 2" do
      need_id = "d1:DB:SELECT * FROM users WHERE id = ?:999"
      bindings = %{need_id => %{"rows" => []}}

      {_conn, result} =
        D1.query_one(new_conn(bindings), "DB", "SELECT * FROM users WHERE id = ?", ["999"])

      assert result == nil
    end
  end

  describe "exec/4" do
    test "adds d1_exec effect" do
      conn = D1.exec(new_conn(), "DB", "INSERT INTO users (name) VALUES (?)", ["Alice"])
      [effect] = conn["_effects"]
      assert effect["type"] == "d1_exec"
      assert effect["db"] == "DB"
      assert effect["sql"] == "INSERT INTO users (name) VALUES (?)"
      assert effect["params"] == ["Alice"]
    end

    test "omits params when empty" do
      conn = D1.exec(new_conn(), "DB", "DELETE FROM cache")
      [effect] = conn["_effects"]
      refute Map.has_key?(effect, "params")
    end
  end

  describe "batch/3" do
    test "adds d1_batch effect" do
      stmts = [
        %{"sql" => "INSERT INTO a (x) VALUES (?)", "params" => ["1"]},
        %{"sql" => "INSERT INTO b (y) VALUES (?)", "params" => ["2"]}
      ]

      conn = D1.batch(new_conn(), "DB", stmts)
      [effect] = conn["_effects"]
      assert effect["type"] == "d1_batch"
      assert effect["db"] == "DB"
      assert length(effect["statements"]) == 2
    end
  end
end
