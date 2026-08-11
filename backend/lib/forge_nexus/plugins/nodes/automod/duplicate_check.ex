defmodule ForgeNexus.Plugins.Nodes.Automod.DuplicateCheck do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour
  import Ecto.Query

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    lookback_minutes = Map.get(config, "lookback_minutes", 60) |> to_number()
    similarity_threshold = Map.get(config, "similarity_threshold", 0.8) |> to_number()

    cutoff = DateTime.utc_now() |> DateTime.add(-trunc(lookback_minutes * 60), :second)

    recent_bodies =
      from(p in ForgeNexus.Forums.Post,
        where: p.user_id == ^user_id and p.inserted_at >= ^cutoff,
        order_by: [desc: p.inserted_at],
        limit: 25,
        select: p.body
      )
      |> ForgeNexus.Repo.all()

    norm = String.downcase(String.trim(content || ""))

    {best_sim, best_match} =
      Enum.reduce(recent_bodies, {0.0, ""}, fn body, {acc_sim, acc_body} ->
        sim = jaccard(norm, String.downcase(String.trim(body || "")))
        if sim > acc_sim, do: {sim, body}, else: {acc_sim, acc_body}
      end)

    ctx = Sandbox.increment_db_ops(ctx)

    if best_sim >= similarity_threshold do
      {:branch, "duplicate", %{similar_content: best_match, similarity: Float.round(best_sim, 3)},
       ctx}
    else
      {:branch, "unique", %{content: content}, ctx}
    end
  end

  defp jaccard("", _), do: 0.0
  defp jaccard(_, ""), do: 0.0

  defp jaccard(a, b) do
    sa = a |> String.split(~r/\s+/) |> MapSet.new()
    sb = b |> String.split(~r/\s+/) |> MapSet.new()
    inter = MapSet.intersection(sa, sb) |> MapSet.size()
    union = MapSet.union(sa, sb) |> MapSet.size()
    if union == 0, do: 0.0, else: inter / union
  end

  defp to_number(v) when is_number(v), do: v

  defp to_number(v) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "automod/duplicate_check",
      category: "automod",
      label: "Duplicate Check",
      description: "Checks if content is a duplicate of recent posts by the same user.",
      inputs: [
        %{name: "content", type: "string", required: true},
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "unique", type: "branch", fields: [%{name: "content", type: "string"}]},
        %{
          name: "duplicate",
          type: "branch",
          fields: [
            %{name: "similar_content", type: "string"},
            %{name: "similarity", type: "number"}
          ]
        }
      ],
      config_fields: [
        %{
          name: "lookback_minutes",
          type: "number",
          default: 60,
          description: "How far back to check for duplicates (minutes)"
        },
        %{
          name: "similarity_threshold",
          type: "number",
          default: 0.8,
          description: "Similarity threshold (0.0-1.0)"
        }
      ]
    }
  end
end
