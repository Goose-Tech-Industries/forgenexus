defmodule ForgeNexus.Plugins.Nodes.Inventory.DefineItem do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Inventory

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    attrs = %{
      name: Map.get(inputs, :name) || Map.get(inputs, "name"),
      description: Map.get(inputs, :description) || Map.get(inputs, "description") || "",
      rarity: Map.get(inputs, :rarity) || Map.get(inputs, "rarity") || "common",
      category: Map.get(inputs, :category) || Map.get(inputs, "category") || "general",
      is_tradeable: Map.get(config, "is_tradeable", true),
      is_stackable: Map.get(config, "is_stackable", true),
      is_consumable: Map.get(config, "is_consumable", false),
      max_stack: Map.get(config, "max_stack", 99),
      icon: Map.get(config, "icon", "")
    }

    case Inventory.create_item_template(attrs) do
      {:ok, template} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{item_template_id: template.id, success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, reason, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/define_item",
      category: "inventory",
      label: "Define Item",
      description: "Creates an item template definition.",
      inputs: [
        %{name: "name", type: "string", required: true},
        %{name: "description", type: "string", required: false},
        %{name: "rarity", type: "string", required: false},
        %{name: "category", type: "string", required: false}
      ],
      outputs: [
        %{name: "item_template_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "is_tradeable",
          type: "boolean",
          default: true,
          description: "Whether the item can be traded"
        },
        %{
          name: "is_stackable",
          type: "boolean",
          default: true,
          description: "Whether the item stacks"
        },
        %{
          name: "is_consumable",
          type: "boolean",
          default: false,
          description: "Whether the item is consumed on use"
        },
        %{name: "max_stack", type: "number", default: 99, description: "Maximum stack size"},
        %{name: "icon", type: "string", default: "", description: "Icon identifier or URL"}
      ]
    }
  end
end
