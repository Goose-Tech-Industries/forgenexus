defmodule ForgeNexus.Collections do
  @moduledoc "Collectible sets, items, and user progress tracking."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Collections.{CollectionSet, CollectionItem, UserCollection}

  def list_sets do
    CollectionSet
    |> where([s], s.is_active == true)
    |> preload(:items)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_set!(id), do: Repo.get!(CollectionSet, id) |> Repo.preload(:items)

  def create_set(attrs), do: %CollectionSet{} |> CollectionSet.changeset(attrs) |> Repo.insert()

  def add_items_to_set(set_id, items_attrs) do
    results =
      Enum.map(items_attrs, fn attrs ->
        %CollectionItem{}
        |> CollectionItem.changeset(Map.put(attrs, :collection_set_id, set_id))
        |> Repo.insert()
      end)

    errors = Enum.filter(results, fn {status, _} -> status == :error end)

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, item} -> item end)}
    else
      {:error, errors}
    end
  end

  def add_to_user_collection(user_id, collection_item_id) do
    case Repo.one(
           from uc in UserCollection,
             where: uc.user_id == ^user_id and uc.collection_item_id == ^collection_item_id
         ) do
      nil ->
        result =
          %UserCollection{}
          |> UserCollection.changeset(%{user_id: user_id, collection_item_id: collection_item_id})
          |> Repo.insert()

        case result do
          {:ok, _uc} ->
            item = Repo.get!(CollectionItem, collection_item_id)
            progress = get_user_progress(user_id, item.collection_set_id)
            {:ok, progress}

          error ->
            error
        end

      _existing ->
        {:error, :already_collected}
    end
  end

  def get_user_progress(user_id, set_id) do
    items =
      Repo.all(
        from ci in CollectionItem, where: ci.collection_set_id == ^set_id, order_by: ci.sort_order
      )

    collected_ids =
      Repo.all(
        from uc in UserCollection,
          join: ci in CollectionItem,
          on: uc.collection_item_id == ci.id,
          where: uc.user_id == ^user_id and ci.collection_set_id == ^set_id,
          select: uc.collection_item_id
      )
      |> MapSet.new()

    items_with_status =
      Enum.map(items, fn item ->
        Map.put(item, :collected?, MapSet.member?(collected_ids, item.id))
      end)

    {MapSet.size(collected_ids), length(items), items_with_status}
  end

  def check_completion?(user_id, set_id) do
    {collected, total, _} = get_user_progress(user_id, set_id)
    collected == total and total > 0
  end

  def get_missing_items(user_id, set_id) do
    {_, _, items} = get_user_progress(user_id, set_id)
    Enum.reject(items, fn item -> item.collected? end)
  end

  # --- Plugin-node friendly API ---

  def define_set(attrs) do
    create_set(attrs)
  end

  def add_to_set(user_id, collection_item_id) do
    add_to_user_collection(user_id, collection_item_id)
  end

  def get_progress(user_id, set_id) do
    {collected, total, items} = get_user_progress(user_id, set_id)

    {:ok,
     %{
       collected: collected,
       total: total,
       items: items,
       complete: total > 0 and collected == total
     }}
  end

  def get_missing(user_id, set_id) do
    {:ok, get_missing_items(user_id, set_id)}
  end

  def trade_item(from_user_id, to_user_id, collection_item_id) do
    Repo.transaction(fn ->
      case Repo.one(
             from uc in UserCollection,
               where: uc.user_id == ^from_user_id and uc.collection_item_id == ^collection_item_id
           ) do
        nil ->
          Repo.rollback(:not_owned)

        uc ->
          Repo.delete!(uc)

          case add_to_user_collection(to_user_id, collection_item_id) do
            {:ok, _} -> :ok
            {:error, reason} -> Repo.rollback(reason)
          end
      end
    end)
  end
end
