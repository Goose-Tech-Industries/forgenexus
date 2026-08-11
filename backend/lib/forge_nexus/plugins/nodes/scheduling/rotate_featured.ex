defmodule ForgeNexus.Plugins.Nodes.Scheduling.RotateFeatured do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour
  import Ecto.Query

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    forum_slug = Map.get(config, "forum_slug", "")
    count = Map.get(config, "count", 5) |> to_int()
    criteria = Map.get(config, "criteria", "newest")

    case ForgeNexus.Forums.get_forum_by_slug(forum_slug) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Forum not found: #{forum_slug}", ctx}

      forum ->
        base =
          from(t in ForgeNexus.Forums.Thread,
            where: t.forum_id == ^forum.id and t.is_hidden == false,
            select: %{id: t.id, title: t.title}
          )

        query =
          case criteria do
            "most_replies" -> from(t in base, order_by: [desc: t.reply_count], limit: ^count)
            "most_views" -> from(t in base, order_by: [desc: t.view_count], limit: ^count)
            "random" -> from(t in base, order_by: fragment("RANDOM()"), limit: ^count)
            _ -> from(t in base, order_by: [desc: t.inserted_at], limit: ^count)
          end

        threads = ForgeNexus.Repo.all(query)

        ids = Enum.map(threads, & &1.id)

        from(t in ForgeNexus.Forums.Thread, where: t.id in ^ids)
        |> ForgeNexus.Repo.update_all(set: [is_pinned: true])

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{featured_threads: threads, success: true}, ctx}
    end
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: trunc(v)

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_int(_), do: 0

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "forum_slug") do
          nil -> ["forum_slug is required" | e]
          "" -> ["forum_slug is required" | e]
          _ -> e
        end
      end)
      |> then(fn e ->
        if Map.get(config, "criteria", "newest") in ~w(newest most_replies most_views random),
          do: e,
          else: ["criteria must be newest, most_replies, most_views, or random" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "scheduling/rotate_featured",
      category: "scheduling",
      label: "Rotate Featured",
      description: "Selects threads to feature based on criteria and rotates them on schedule.",
      inputs: [],
      outputs: [
        %{name: "featured_threads", type: "list"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "forum_slug",
          type: "string",
          default: "",
          description: "Forum to select featured threads from"
        },
        %{name: "count", type: "number", default: 5, description: "Number of threads to feature"},
        %{
          name: "criteria",
          type: "select",
          options: ~w(newest most_replies most_views random),
          default: "newest",
          description: "Selection criteria for featured threads"
        }
      ]
    }
  end
end
