defmodule ForgeNexus.Plugins.Nodes.Poll.ClosePoll do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    poll_id = Map.get(inputs, :poll_id) || Map.get(inputs, "poll_id")

    case ForgeNexus.Forums.Polls.close_poll(poll_id) do
      {:ok, _poll} ->
        results = ForgeNexus.Forums.Polls.get_results(poll_id, nil)

        winner =
          results.options
          |> Enum.max_by(& &1.vote_count, fn -> %{text: ""} end)
          |> Map.get(:text, "")

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{winner: winner, results: results.options, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to close poll: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "poll/close_poll",
      category: "poll",
      label: "Close Poll",
      description: "Closes a poll and determines the winning option.",
      inputs: [%{name: "poll_id", type: "string", required: true}],
      outputs: [
        %{name: "winner", type: "string"},
        %{name: "results", type: "list"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
