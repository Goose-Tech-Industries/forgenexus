defmodule ForgeNexus.Plugins.Nodes.Poll.AddVote do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    poll_id = Map.get(inputs, :poll_id) || Map.get(inputs, "poll_id")
    option_index = Map.get(inputs, :option_index) || Map.get(inputs, "option_index", 0)

    poll = ForgeNexus.Forums.Polls.get_results(poll_id, user_id)
    sorted_options = poll.options

    case Enum.at(sorted_options, option_index) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Invalid option_index #{option_index}", ctx}

      opt ->
        case ForgeNexus.Forums.Polls.vote(poll_id, user_id, [opt.id]) do
          {:ok, _} ->
            updated = ForgeNexus.Forums.Polls.get_results(poll_id, user_id)

            count =
              (Enum.find(updated.options, &(&1.id == opt.id)) || %{vote_count: 0}).vote_count

            ctx = Sandbox.increment_db_ops(ctx)
            {:ok, %{success: true, current_count: count}, ctx}

          {:error, reason} ->
            ctx = Sandbox.increment_db_ops(ctx)
            {:error, "Failed to vote: #{inspect(reason)}", ctx}
        end
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "poll/add_vote",
      category: "poll",
      label: "Add Vote",
      description: "Records a user's vote on a poll option.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "poll_id", type: "string", required: true},
        %{name: "option_index", type: "number", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "current_count", type: "number"}
      ],
      config_fields: []
    }
  end
end
