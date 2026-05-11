defmodule ForgeNexus.Plugins.Nodes.Poll.CreatePrediction do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    question = Map.get(inputs, :question) || Map.get(inputs, "question")
    options_raw = Map.get(config, "options", "")
    closes_in_hours = Map.get(config, "closes_in_hours", 24) |> to_number()
    _currency_slug = Map.get(config, "currency_slug", "points")

    options =
      options_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if length(options) < 2 do
      {:error, "Prediction must have at least 2 options", ctx}
    else
      closes_at =
        DateTime.utc_now()
        |> DateTime.add(trunc(closes_in_hours * 3600), :second)
        |> DateTime.truncate(:second)

      attrs = %{title: question, status: "open", closes_at: closes_at}

      case ForgeNexus.Predictions.create_prediction(attrs) do
        {:ok, prediction} ->
          for label <- options do
            %ForgeNexus.Predictions.PredictionOption{}
            |> ForgeNexus.Predictions.PredictionOption.changeset(%{
              prediction_id: prediction.id,
              label: label
            })
            |> ForgeNexus.Repo.insert()
          end

          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{prediction_id: prediction.id, success: true}, ctx}

        {:error, err} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, "Failed to create prediction: #{inspect(err)}", ctx}
      end
    end
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
  def validate_config(config) do
    case Map.get(config, "options") do
      nil ->
        {:error, ["options is required"]}

      "" ->
        {:error, ["options cannot be empty"]}

      opts when is_binary(opts) ->
        parsed = opts |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        if length(parsed) < 2, do: {:error, ["at least 2 options are required"]}, else: :ok

      _ ->
        {:error, ["options must be a comma-separated string"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "poll/create_prediction",
      category: "poll",
      label: "Create Prediction",
      description: "Creates a prediction market where users wager currency on outcomes.",
      inputs: [%{name: "question", type: "string", required: true}],
      outputs: [
        %{name: "prediction_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "options", type: "string", default: "", description: "Comma-separated prediction options"},
        %{name: "closes_in_hours", type: "number", default: 24, description: "Hours until prediction closes for new wagers"},
        %{name: "currency_slug", type: "string", default: "points", description: "Currency used for wagers"}
      ]
    }
  end
end
