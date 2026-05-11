defmodule ForgeNexus.Plugins.Nodes.Verification.CreateIntroductionPrompt do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    intro_forum_slug = Map.get(config, "intro_forum_slug", "introductions")
    template = Map.get(config, "template", "Welcome to the community! Tell us about yourself.")

    case ForgeNexus.Forums.get_forum_by_slug(intro_forum_slug) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{thread_id: nil, success: false}, ctx}

      forum ->
        title = "Introduction"

        slug =
          "introduction-#{:rand.uniform(10_000_000)}"
          |> String.downcase()

        thread_attrs = %{
          forum_id: forum.id,
          user_id: user_id,
          title: title,
          slug: slug,
          last_post_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        case ForgeNexus.Forums.create_thread(thread_attrs) do
          {:ok, thread} ->
            ForgeNexus.Forums.create_post(%{
              thread_id: thread.id,
              forum_id: forum.id,
              user_id: user_id,
              body: template
            })

            ctx = Sandbox.increment_db_ops(ctx)
            {:ok, %{thread_id: thread.id, success: true}, ctx}

          {:error, err} ->
            ctx = Sandbox.increment_db_ops(ctx)
            {:error, "Failed to create intro thread: #{inspect(err)}", ctx}
        end
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "verification/create_introduction_prompt",
      category: "verification",
      label: "Create Introduction Prompt",
      description: "Creates an introduction thread for a new user in a designated forum.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "thread_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "intro_forum_slug", type: "string", default: "introductions", description: "Slug of the forum for introduction threads"},
        %{name: "template", type: "text", default: "Welcome to the community! Tell us about yourself.", description: "Template for the introduction post"}
      ]
    }
  end
end
