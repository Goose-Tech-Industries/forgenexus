defmodule ForgeNexus.Inventory do
  @moduledoc "Item templates, user inventories, crafting, and equipment."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Inventory.{ItemTemplate, InventoryItem, CraftingRecipe}

  # Item Templates

  def get_item_template!(id), do: Repo.get!(ItemTemplate, id)

  def get_item_template_by_slug(slug), do: Repo.get_by(ItemTemplate, slug: slug)

  def list_item_templates, do: ItemTemplate |> order_by(:name) |> Repo.all()

  def create_item_template(attrs),
    do: %ItemTemplate{} |> ItemTemplate.changeset(attrs) |> Repo.insert()

  # Inventory Operations

  def give_item(user_id, item_template_id, quantity \\ 1) do
    template = get_item_template!(item_template_id)

    if template.is_stackable do
      case Repo.one(
             from ii in InventoryItem,
               where: ii.user_id == ^user_id and ii.item_template_id == ^item_template_id
           ) do
        nil ->
          %InventoryItem{}
          |> InventoryItem.changeset(%{
            user_id: user_id,
            item_template_id: item_template_id,
            quantity: quantity
          })
          |> Repo.insert()

        existing ->
          new_qty = min(existing.quantity + quantity, template.max_stack)
          existing |> InventoryItem.changeset(%{quantity: new_qty}) |> Repo.update()
      end
    else
      results =
        Enum.map(1..quantity, fn _ ->
          %InventoryItem{}
          |> InventoryItem.changeset(%{
            user_id: user_id,
            item_template_id: item_template_id,
            quantity: 1
          })
          |> Repo.insert()
        end)

      case Enum.find(results, fn {status, _} -> status == :error end) do
        nil -> {:ok, Enum.map(results, fn {:ok, item} -> item end)}
        error -> error
      end
    end
  end

  def remove_item(user_id, item_template_id, quantity \\ 1) do
    case Repo.one(
           from ii in InventoryItem,
             where: ii.user_id == ^user_id and ii.item_template_id == ^item_template_id,
             limit: 1
         ) do
      nil ->
        {:error, :item_not_found}

      item ->
        new_qty = item.quantity - quantity

        if new_qty <= 0,
          do: Repo.delete(item),
          else: item |> InventoryItem.changeset(%{quantity: new_qty}) |> Repo.update()
    end
  end

  def has_item?(user_id, item_template_id) do
    Repo.exists?(
      from ii in InventoryItem,
        where:
          ii.user_id == ^user_id and ii.item_template_id == ^item_template_id and ii.quantity > 0
    )
  end

  def get_inventory(user_id) do
    InventoryItem
    |> where([ii], ii.user_id == ^user_id and ii.quantity > 0)
    |> preload(:item_template)
    |> order_by(:inserted_at)
    |> Repo.all()
  end

  def transfer_item(from_user_id, to_user_id, item_template_id, quantity) do
    Repo.transaction(fn ->
      case remove_item(from_user_id, item_template_id, quantity) do
        {:ok, _} ->
          case give_item(to_user_id, item_template_id, quantity) do
            {:ok, item} -> item
            {:error, changeset} -> Repo.rollback(changeset)
          end

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  def equip_item(user_id, inventory_item_id) do
    item =
      Repo.one!(
        from ii in InventoryItem,
          where: ii.id == ^inventory_item_id and ii.user_id == ^user_id,
          preload: :item_template
      )

    Repo.transaction(fn ->
      from(ii in InventoryItem,
        join: t in ItemTemplate,
        on: ii.item_template_id == t.id,
        where:
          ii.user_id == ^user_id and ii.is_equipped == true and
            t.category == ^item.item_template.category and ii.id != ^inventory_item_id
      )
      |> Repo.update_all(set: [is_equipped: false])

      item |> InventoryItem.changeset(%{is_equipped: true}) |> Repo.update!()
    end)
  end

  def consume_item(user_id, inventory_item_id) do
    item =
      Repo.one!(
        from ii in InventoryItem,
          where: ii.id == ^inventory_item_id and ii.user_id == ^user_id,
          preload: :item_template
      )

    template = item.item_template

    case remove_item(user_id, template.id, 1) do
      {:ok, _} -> {:ok, template}
      error -> error
    end
  end

  # Crafting

  def get_crafting_recipes do
    CraftingRecipe |> where([r], r.is_active == true) |> preload(:result_item) |> Repo.all()
  end

  def craft_item(user_id, recipe_id) do
    recipe = Repo.get!(CraftingRecipe, recipe_id) |> Repo.preload(:result_item)

    Repo.transaction(fn ->
      Enum.each(recipe.ingredients, fn %{"item_template_id" => tmpl_id, "quantity" => qty} ->
        unless has_item?(user_id, tmpl_id), do: Repo.rollback(:missing_ingredient)

        case remove_item(user_id, tmpl_id, qty) do
          {:ok, _} -> :ok
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

      if :rand.uniform() <= recipe.success_rate do
        case give_item(user_id, recipe.result_item_id, recipe.result_quantity) do
          {:ok, item} -> {:success, item}
          {:error, changeset} -> Repo.rollback(changeset)
        end
      else
        :failed
      end
    end)
  end
end
