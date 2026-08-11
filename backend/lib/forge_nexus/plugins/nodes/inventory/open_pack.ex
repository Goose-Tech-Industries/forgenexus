defmodule ForgeNexus.Plugins.Nodes.Inventory.OpenPack do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    pack_template_id = Map.get(inputs, :pack_template_id) || Map.get(inputs, "pack_template_id")
    items_count = Map.get(config, "items_count", 5) |> to_int()

    case ForgeNexus.Inventory.consume_item(user_id, pack_template_id) do
      {:ok, _} ->
        templates = ForgeNexus.Inventory.list_item_templates()

        chosen =
          if templates == [] do
            []
          else
            for _ <- 1..items_count, do: Enum.random(templates)
          end

        items =
          Enum.map(chosen, fn t ->
            ForgeNexus.Inventory.give_item(user_id, t.id, 1)
            %{template_id: t.id, name: t.name}
          end)

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{items: items, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to open pack: #{inspect(err)}", ctx}
    end
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: trunc(v)

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> 5
    end
  end

  defp to_int(_), do: 5

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/open_pack",
      category: "inventory",
      label: "Open Pack",
      description:
        "Opens an item pack, consuming it and awarding random items based on rarity weights.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "pack_template_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "items", type: "list"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "items_count",
          type: "number",
          default: 5,
          description: "Number of items in the pack"
        },
        %{
          name: "rates",
          type: "json",
          default: "{}",
          description: "JSON map of rarity => weight for item generation"
        }
      ]
    }
  end
end
