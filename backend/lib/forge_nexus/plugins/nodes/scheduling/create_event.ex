defmodule ForgeNexus.Plugins.Nodes.Scheduling.CreateEvent do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    name = Map.get(inputs, :name) || Map.get(inputs, "name")
    description = Map.get(inputs, :description) || Map.get(inputs, "description")
    starts_at = Map.get(config, "starts_at", "")
    ends_at = Map.get(config, "ends_at", "")
    location = Map.get(config, "location", "")

    starts_dt = parse_dt(starts_at)
    ends_dt = parse_dt(ends_at)

    attrs = %{
      title: name,
      description: description,
      starts_at: starts_dt,
      ends_at: ends_dt,
      location: location
    }

    case ForgeNexus.Events.create_event(attrs) do
      {:ok, event} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{event_id: event.id, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create event: #{inspect(err)}", ctx}
    end
  end

  defp parse_dt(""), do: nil

  defp parse_dt(s) when is_binary(s) do
    case DateTime.from_iso8601(s) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp parse_dt(_), do: nil

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "starts_at") do
          nil -> ["starts_at is required" | e]
          "" -> ["starts_at is required" | e]
          _ -> e
        end
      end)
      |> then(fn e ->
        case Map.get(config, "ends_at") do
          nil -> ["ends_at is required" | e]
          "" -> ["ends_at is required" | e]
          _ -> e
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "scheduling/create_event",
      category: "scheduling",
      label: "Create Event",
      description: "Creates a scheduled community event with start/end times and location.",
      inputs: [
        %{name: "name", type: "string", required: true},
        %{name: "description", type: "string", required: true}
      ],
      outputs: [
        %{name: "event_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "starts_at",
          type: "string",
          default: "",
          description: "Event start time (ISO 8601)"
        },
        %{name: "ends_at", type: "string", default: "", description: "Event end time (ISO 8601)"},
        %{
          name: "location",
          type: "string",
          default: "",
          description: "Event location (URL or text)"
        }
      ]
    }
  end
end
