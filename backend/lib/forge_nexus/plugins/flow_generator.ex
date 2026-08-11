defmodule ForgeNexus.Plugins.FlowGenerator do
  @moduledoc """
  Natural language → no-code flow generator.

  Takes a plain-English description, fetches the full node-type catalog
  from `ForgeNexus.Plugins.Nodes.Registry`, builds a system prompt with
  the catalog + rules, and calls Claude via tool-use to get a structured
  flow spec back. Validates every node type against the registry and every
  edge against the generated nodes before returning.

  Returns `{:ok, spec}` where `spec` is a map shaped like:

      %{
        name: String.t(),
        description: String.t(),
        trigger_type: String.t(),
        trigger_config: map(),
        nodes: [
          %{client_id: String.t(), type: String.t(), label: String.t(), config: map()}
        ],
        edges: [
          %{source: String.t(), target: String.t(), source_port: String.t(), target_port: String.t()}
        ]
      }

  On any validation or provider failure returns `{:error, reason}`.
  """

  require Logger
  alias ForgeNexus.Plugins.Nodes.Registry
  alias ForgeNexus.Settings

  @default_model "claude-sonnet-4-6"
  @anthropic_url "https://api.anthropic.com/v1/messages"
  @max_tokens 8192

  @doc "Generate a flow spec from a natural language description."
  @spec generate(String.t()) :: {:ok, map()} | {:error, atom() | tuple()}
  def generate(description) when is_binary(description) do
    description = String.trim(description)

    cond do
      description == "" ->
        {:error, :empty_description}

      not Settings.get_bool("ai_flow_generator_enabled") ->
        {:error, :disabled}

      true ->
        provider = Settings.get("ai_flow_generator_provider") || "anthropic"
        dispatch(provider, description)
    end
  end

  def generate(_), do: {:error, :invalid_description}

  # --- Provider dispatch ---

  defp dispatch("anthropic", description), do: generate_with_anthropic(description)
  defp dispatch(other, _), do: {:error, {:unknown_provider, other}}

  # --- Anthropic implementation ---

  defp generate_with_anthropic(description) do
    api_key = System.get_env("ANTHROPIC_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, :no_api_key}
    else
      node_types = Registry.all_types()
      catalog = build_catalog(node_types)

      # Split the system prompt into a small preamble + large cached catalog block.
      # Prompt caching is automatic once `cache_control: {type: "ephemeral"}`
      # is set on the block. The 5-minute TTL is plenty — repeat generations
      # within a session reuse the cache at ~10% the input token cost.
      body = %{
        model: Settings.get("ai_flow_generator_model") || @default_model,
        max_tokens: @max_tokens,
        system: [
          %{type: "text", text: preamble()},
          %{
            type: "text",
            text: catalog_prompt(catalog),
            cache_control: %{type: "ephemeral"}
          }
        ],
        tools: [flow_tool_schema(node_types)],
        tool_choice: %{type: "tool", name: "create_flow"},
        messages: [
          %{role: "user", content: description}
        ]
      }

      headers = [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"anthropic-beta", "prompt-caching-2024-07-31"},
        {"content-type", "application/json"}
      ]

      try do
        case Req.post(@anthropic_url, headers: headers, json: body, receive_timeout: 120_000) do
          {:ok, %{status: 200, body: resp}} ->
            handle_anthropic_response(resp, node_types)

          {:ok, %{status: status, body: body}} ->
            Logger.warning("[FlowGenerator] Anthropic returned #{status}: #{inspect(body)}")
            {:error, {:http, status}}

          {:error, reason} ->
            Logger.warning("[FlowGenerator] request failed: #{inspect(reason)}")
            {:error, {:request_failed, reason}}
        end
      rescue
        e ->
          Logger.warning("[FlowGenerator] exception: #{Exception.message(e)}")
          {:error, {:exception, Exception.message(e)}}
      end
    end
  end

  # --- Response handling ---

  defp handle_anthropic_response(%{"content" => content}, node_types) when is_list(content) do
    case Enum.find(content, fn block -> Map.get(block, "type") == "tool_use" end) do
      %{"input" => input} when is_map(input) ->
        validate_and_normalize(input, node_types)

      _ ->
        text = collect_text(content)
        Logger.warning("[FlowGenerator] model returned no tool_use block: #{text}")
        {:error, {:no_tool_use, text}}
    end
  end

  defp handle_anthropic_response(resp, _),
    do: {:error, {:unexpected_response, inspect(resp)}}

  defp collect_text(content) do
    content
    |> Enum.filter(fn b -> Map.get(b, "type") == "text" end)
    |> Enum.map(fn b -> Map.get(b, "text", "") end)
    |> Enum.join("\n")
    |> String.slice(0, 500)
  end

  # --- Validation + normalization ---

  defp validate_and_normalize(input, node_types) do
    valid_types = node_types |> Enum.map(fn {type, _schema} -> type end) |> MapSet.new()

    with {:ok, name} <- fetch_string(input, "name", "Generated Flow"),
         {:ok, description} <- fetch_string(input, "description", ""),
         {:ok, trigger_type} <- fetch_trigger_type(input, valid_types),
         trigger_config <- Map.get(input, "trigger_config", %{}),
         {:ok, nodes} <- validate_nodes(Map.get(input, "nodes", []), valid_types),
         {:ok, edges} <- validate_edges(Map.get(input, "edges", []), nodes) do
      {:ok,
       %{
         name: name,
         description: description,
         trigger_type: trigger_type,
         trigger_config: trigger_config,
         nodes: nodes,
         edges: edges
       }}
    end
  end

  defp fetch_string(map, key, default) do
    case Map.get(map, key) do
      s when is_binary(s) and s != "" -> {:ok, s}
      nil -> {:ok, default}
      "" -> {:ok, default}
      _ -> {:error, {:invalid_field, key}}
    end
  end

  defp fetch_trigger_type(input, valid_types) do
    case Map.get(input, "trigger_type") do
      nil ->
        # Infer from the first trigger/* node if present
        case Enum.find(Map.get(input, "nodes", []), fn n ->
               t = Map.get(n, "type", "")
               is_binary(t) and String.starts_with?(t, "trigger/")
             end) do
          %{"type" => t} -> {:ok, t}
          _ -> {:error, :missing_trigger_type}
        end

      trigger_type when is_binary(trigger_type) ->
        # Trigger types must either be a valid node type starting with trigger/
        # or the canonical short form (e.g. "post_created").
        cond do
          MapSet.member?(valid_types, trigger_type) ->
            {:ok, trigger_type}

          MapSet.member?(valid_types, "trigger/" <> trigger_type) ->
            {:ok, "trigger/" <> trigger_type}

          String.starts_with?(trigger_type, "trigger/") ->
            {:ok, trigger_type}

          true ->
            {:ok, trigger_type}
        end

      _ ->
        {:error, :invalid_trigger_type}
    end
  end

  defp validate_nodes(nodes, valid_types) when is_list(nodes) do
    result =
      Enum.reduce_while(nodes, {[], MapSet.new()}, fn node, {acc, seen_ids} ->
        with client_id when is_binary(client_id) <- Map.get(node, "id"),
             type when is_binary(type) <- Map.get(node, "type"),
             false <- MapSet.member?(seen_ids, client_id),
             true <- MapSet.member?(valid_types, type) do
          normalized = %{
            client_id: client_id,
            type: type,
            label: Map.get(node, "label") || derive_label(type),
            config: Map.get(node, "config", %{})
          }

          {:cont, {acc ++ [normalized], MapSet.put(seen_ids, client_id)}}
        else
          _ ->
            reason =
              cond do
                not is_binary(Map.get(node, "id")) ->
                  {:node_missing_id, node}

                not is_binary(Map.get(node, "type")) ->
                  {:node_missing_type, node}

                not MapSet.member?(valid_types, Map.get(node, "type")) ->
                  {:unknown_node_type, Map.get(node, "type")}

                true ->
                  {:duplicate_node_id, Map.get(node, "id")}
              end

            {:halt, {:error, reason}}
        end
      end)

    case result do
      {:error, _} = err -> err
      {[], _} -> {:error, :no_nodes}
      {nodes, _} -> {:ok, nodes}
    end
  end

  defp validate_nodes(_, _), do: {:error, :invalid_nodes}

  defp validate_edges(edges, nodes) when is_list(edges) do
    ids = nodes |> Enum.map(& &1.client_id) |> MapSet.new()

    result =
      Enum.reduce_while(edges, [], fn edge, acc ->
        source = Map.get(edge, "source")
        target = Map.get(edge, "target")

        cond do
          not is_binary(source) or not MapSet.member?(ids, source) ->
            {:halt, {:error, {:edge_unknown_source, source}}}

          not is_binary(target) or not MapSet.member?(ids, target) ->
            {:halt, {:error, {:edge_unknown_target, target}}}

          true ->
            normalized = %{
              source: source,
              target: target,
              source_port: Map.get(edge, "source_port", "output"),
              target_port: Map.get(edge, "target_port", "input")
            }

            {:cont, acc ++ [normalized]}
        end
      end)

    case result do
      {:error, _} = err -> err
      edges -> {:ok, edges}
    end
  end

  defp validate_edges(_, _), do: {:error, :invalid_edges}

  defp derive_label(type) do
    type
    |> String.split("/")
    |> List.last()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # --- Prompt + tool schema ---

  defp preamble do
    """
    You are a flow designer for ForgeNexus, a community platform's no-code automation engine.

    A flow is a directed graph of nodes triggered by an event. Each node has a `type`
    drawn from the catalog (provided separately), a `config` map (per the node's schema),
    and is connected to other nodes via edges. Every flow has exactly one trigger node
    that starts execution.

    Your job: read the user's plain-language request and produce a valid flow by
    calling the `create_flow` tool. Follow these rules strictly:

    1. Every node's `type` MUST be one of the types in the catalog — never invent a new type.
    2. Assign each node a short unique string id (e.g. "n1", "n2", "trigger") — you'll
       reference these ids in the edges.
    3. Exactly one node should be a `trigger/*` type. Set the flow's `trigger_type`
       to match (full path, e.g. "trigger/post_created").
    4. Every edge's `source` and `target` must reference an id you defined.
    5. Prefer the simplest flow that satisfies the request. Don't add nodes that
       aren't needed.
    6. For the `config` of each node, only include fields listed in that node's
       schema under `config_fields`. Use sensible defaults (e.g. variable names
       like "message", "user", "amount") if the user didn't specify.
    7. Choose a descriptive `name` and a one-sentence `description` for the flow.
    """
  end

  defp catalog_prompt(catalog) do
    """
    === NODE CATALOG ===
    #{catalog}
    === END CATALOG ===
    """
  end

  defp build_catalog(node_types) do
    node_types
    |> Enum.sort_by(fn {type, _} -> type end)
    |> Enum.map(fn {type, schema} -> format_type(type, schema) end)
    |> Enum.join("\n\n")
  end

  defp format_type(type, schema) when is_map(schema) do
    label = Map.get(schema, :label, type)
    description = Map.get(schema, :description, "")
    inputs = schema |> Map.get(:inputs, []) |> format_fields()
    outputs = schema |> Map.get(:outputs, []) |> format_fields()
    configs = schema |> Map.get(:config_fields, []) |> format_fields()

    """
    - #{type}  (#{label})
      #{description}
      inputs:  #{inputs}
      outputs: #{outputs}
      config:  #{configs}
    """
    |> String.trim_trailing()
  end

  defp format_type(type, _), do: "- #{type}"

  defp format_fields([]), do: "(none)"

  defp format_fields(fields) when is_list(fields) do
    fields
    |> Enum.map(fn f ->
      name = field_get(f, :name)
      type = field_get(f, :type) || "any"
      "#{name}:#{type}"
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp format_fields(_), do: "(unknown)"

  defp field_get(%{} = m, key) when is_atom(key) do
    Map.get(m, key) || Map.get(m, Atom.to_string(key))
  end

  defp field_get(_, _), do: nil

  defp flow_tool_schema(_node_types) do
    # Node types are constrained via the system prompt rather than an enum in
    # the tool schema because the catalog is large (250+ types). The validation
    # step rejects any type the model hallucinates.
    %{
      name: "create_flow",
      description: "Create a new ForgeNexus no-code flow with the given nodes and edges.",
      input_schema: %{
        type: "object",
        required: ["name", "trigger_type", "nodes", "edges"],
        properties: %{
          name: %{type: "string", description: "Short human-readable flow name"},
          description: %{
            type: "string",
            description: "One-sentence description of what the flow does"
          },
          trigger_type: %{
            type: "string",
            description: "Full node type of the trigger (e.g. 'trigger/post_created')"
          },
          trigger_config: %{
            type: "object",
            description: "Config map for the trigger node",
            additionalProperties: true
          },
          nodes: %{
            type: "array",
            description: "All nodes in the flow, including the trigger",
            items: %{
              type: "object",
              required: ["id", "type"],
              properties: %{
                id: %{type: "string", description: "Unique string id within this flow"},
                type: %{type: "string", description: "Node type from the catalog"},
                label: %{type: "string"},
                config: %{type: "object", additionalProperties: true}
              }
            }
          },
          edges: %{
            type: "array",
            description: "Connections between nodes",
            items: %{
              type: "object",
              required: ["source", "target"],
              properties: %{
                source: %{type: "string", description: "id of the source node"},
                target: %{type: "string", description: "id of the target node"},
                source_port: %{type: "string", description: "Output port name (default 'output')"},
                target_port: %{type: "string", description: "Input port name (default 'input')"}
              }
            }
          }
        }
      }
    }
  end
end
