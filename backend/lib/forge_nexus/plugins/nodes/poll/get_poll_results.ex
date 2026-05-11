defmodule ForgeNexus.Plugins.Nodes.Poll.GetPollResults do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    poll_id = Map.get(inputs, :poll_id) || Map.get(inputs, "poll_id")

    poll = ForgeNexus.Forums.Polls.get_results(poll_id, nil)
    ctx = Sandbox.increment_db_ops(ctx)

    {:ok,
     %{
       results: poll.options,
       total_votes: poll.total_votes || 0,
       is_closed: poll.is_closed || false
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "poll/get_poll_results",
      category: "poll",
      label: "Get Poll Results",
      description: "Retrieves current results for a poll including vote counts and percentages.",
      inputs: [%{name: "poll_id", type: "string", required: true}],
      outputs: [
        %{name: "results", type: "list"},
        %{name: "total_votes", type: "number"},
        %{name: "is_closed", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
