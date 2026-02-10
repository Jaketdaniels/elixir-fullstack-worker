defmodule ElixirWorkers.DO do
  @moduledoc false

  alias ElixirWorkers.Conn

  # --- RPC Calls (transparent two-pass) ---

  # Call a Durable Object RPC method and return its value.
  # Pass 1: registers a need, returns {conn, nil}.
  # Pass 2: reads from bindings, returns {conn, value | nil}.
  def call(conn, namespace, name, method, args \\ []) when is_list(args) do
    ns = to_string(namespace)
    do_name = to_string(name)
    rpc_method = to_string(method)
    need_id = need_id(ns, do_name, rpc_method, args)

    case Map.get(conn["bindings"], need_id) do
      nil ->
        need = %{
          "type" => "do_rpc",
          "ns" => ns,
          "name" => do_name,
          "method" => rpc_method,
          "id" => need_id
        }

        need = if args == [], do: need, else: Map.put(need, "args", args)
        {Conn.add_need(conn, need), nil}

      %{"ok" => true, "value" => value} ->
        {conn, value}

      %{"ok" => false, "error" => error} ->
        {conn, %{"error" => error}}

      value ->
        # Backward compatibility for raw bindings
        {conn, value}
    end
  end

  # --- Fire-and-forget RPC effects ---

  def cast(conn, namespace, name, method, args \\ []) when is_list(args) do
    effect = %{
      "type" => "do_rpc",
      "ns" => to_string(namespace),
      "name" => to_string(name),
      "method" => to_string(method)
    }

    effect = if args == [], do: effect, else: Map.put(effect, "args", args)
    Conn.add_effect(conn, effect)
  end

  # --- Internal ---

  defp need_id(namespace, name, method, args) do
    arg_hash = :erlang.phash2(args)

    "do:" <>
      namespace <> ":" <> name <> ":" <> method <> ":" <> :erlang.integer_to_binary(arg_hash)
  end
end
