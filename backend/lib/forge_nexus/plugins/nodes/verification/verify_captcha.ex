defmodule ForgeNexus.Plugins.Nodes.Verification.VerifyCaptcha do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    challenge_id = Map.get(inputs, :challenge_id) || Map.get(inputs, "challenge_id")
    response = Map.get(inputs, :response) || Map.get(inputs, "response")

    case ForgeNexus.Verification.verify_challenge(challenge_id, response) do
      {:ok, challenge} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:branch, "passed", %{attempts: challenge.attempts}, ctx}

      {:error, %{attempts: a}} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:branch, "failed", %{attempts: a}, ctx}

      {:error, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:branch, "failed", %{attempts: 1}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "verification/verify_captcha",
      category: "verification",
      label: "Verify Captcha",
      description: "Verifies a user's captcha response and branches on pass or fail.",
      inputs: [
        %{name: "challenge_id", type: "string", required: true},
        %{name: "response", type: "string", required: true}
      ],
      outputs: [
        %{name: "passed", type: "branch", fields: [%{name: "attempts", type: "number"}]},
        %{name: "failed", type: "branch", fields: [%{name: "attempts", type: "number"}]}
      ],
      config_fields: []
    }
  end
end
