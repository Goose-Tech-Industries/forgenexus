defmodule ForgeNexus.Plugins.Nodes.Content.EditThread do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    thread_id = Map.get(inputs, :thread_id) || Map.get(inputs, "thread_id")
    title = Map.get(inputs, :title) || Map.get(inputs, "title")
    prefix = Map.get(inputs, :prefix) || Map.get(inputs, "prefix")
    tags_raw = Map.get(config, "tags", "")

    updates =
      %{}
      |> then(fn m -> if title, do: Map.put(m, :title, title), else: m end)
      |> then(fn m -> if prefix, do: Map.put(m, :prefix, prefix), else: m end)
      |> then(fn m ->
        if tags_raw != "" do
          tags =
            tags_raw |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

          Map.put(m, :tags, tags)
        else
          m
        end
      end)

    case ForgeNexus.Forums.edit_thread_fields(thread_id, updates) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to edit thread: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "content/edit_thread",
      category: "content",
      label: "Edit Thread",
      description: "Edits a thread's title, prefix, or tags.",
      inputs: [
        %{name: "thread_id", type: "string", required: true},
        %{name: "title", type: "string", required: false},
        %{name: "prefix", type: "string", required: false}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: [
        %{
          name: "tags",
          type: "string",
          default: "",
          description: "Comma-separated tags (optional, replaces existing)"
        }
      ]
    }
  end
end
