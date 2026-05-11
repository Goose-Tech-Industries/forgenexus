defmodule ForgeNexus.Plugins.Nodes.Verification.SendCaptcha do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    captcha_type = Map.get(config, "captcha_type", "math")

    case ForgeNexus.Verification.create_challenge(user_id, captcha_type) do
      {:ok, challenge} ->
        question =
          case Map.get(challenge.challenge_data, "question") || Map.get(challenge.challenge_data, :question) do
            nil -> "Please verify"
            q -> q
          end

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{challenge_id: challenge.id, question: question}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create captcha: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, "captcha_type", "math") in ~w(math text),
      do: :ok,
      else: {:error, ["captcha_type must be math or text"]}
  end

  @impl true
  def schema do
    %{
      type: "verification/send_captcha",
      category: "verification",
      label: "Send Captcha",
      description: "Generates a captcha challenge (math or text) for user verification.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "challenge_id", type: "string"},
        %{name: "question", type: "string"}
      ],
      config_fields: [
        %{name: "captcha_type", type: "select", options: ~w(math text), default: "math", description: "Type of captcha challenge to generate"}
      ]
    }
  end
end
