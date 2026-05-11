defmodule ForgeNexus.Plugins.Nodes.Content.SetThreadPrefix do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    thread_id = Map.get(inputs, :thread_id) || Map.get(inputs, "thread_id")
    prefix = Map.get(inputs, :prefix) || Map.get(inputs, "prefix")

    case ForgeNexus.Forums.update_thread_prefix(thread_id, prefix) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to set prefix: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "content/set_thread_prefix",
      category: "content",
      label: "Set Thread Prefix",
      description: "Sets or changes the prefix tag on a thread.",
      inputs: [
        %{name: "thread_id", type: "string", required: true},
        %{name: "prefix", type: "string", required: true}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
