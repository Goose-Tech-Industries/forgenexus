defmodule ForgeNexus.Plugins.Nodes.Trigger.OnSlashCommand do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       command_name: Map.get(td, :command_name, Map.get(td, "command_name")),
       args: Map.get(td, :args, Map.get(td, "args", "")),
       args_list: Map.get(td, :args_list, Map.get(td, "args_list", [])),
       user: Map.get(td, :user, Map.get(td, "user")),
       raw_input: Map.get(td, :raw_input, Map.get(td, "raw_input", ""))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_slash_command",
      category: "trigger",
      label: "On Slash Command",
      description: "Triggers when a custom slash command is executed.",
      inputs: [],
      outputs: [
        %{name: "command_name", type: "string"},
        %{name: "args", type: "string"},
        %{name: "args_list", type: "list"},
        %{name: "user", type: "map"},
        %{name: "raw_input", type: "string"}
      ],
      config_fields: [
        %{
          name: "command_name",
          type: "string",
          default: "",
          description: "Slash command name to listen for (without leading /)"
        }
      ]
    }
  end
end
