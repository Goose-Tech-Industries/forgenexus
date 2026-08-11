defmodule ForgeNexus.Plugins.Nodes.Content.CreateThreadNode do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    forum_id = Map.get(inputs, :forum_id) || Map.get(inputs, "forum_id")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    title = Map.get(inputs, :title) || Map.get(inputs, "title")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")
    prefix = Map.get(config, "prefix", "")
    tags_raw = Map.get(config, "tags", "")

    tags =
      tags_raw
      |> to_string()
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    slug =
      title
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    attrs = %{
      forum_id: forum_id,
      user_id: user_id,
      title: title,
      slug: slug,
      prefix: if(prefix == "", do: nil, else: prefix),
      tags: tags,
      last_post_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case ForgeNexus.Forums.create_thread(attrs) do
      {:ok, thread} ->
        if body && body != "" do
          ForgeNexus.Forums.create_post(%{
            thread_id: thread.id,
            forum_id: forum_id,
            user_id: user_id,
            body: body
          })
        end

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{thread_id: thread.id, slug: thread.slug, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create thread: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "content/create_thread",
      category: "content",
      label: "Create Thread",
      description: "Creates a new thread with optional prefix and tags.",
      inputs: [
        %{name: "forum_id", type: "string", required: true},
        %{name: "user_id", type: "string", required: true},
        %{name: "title", type: "string", required: true},
        %{name: "body", type: "string", required: true}
      ],
      outputs: [
        %{name: "thread_id", type: "string"},
        %{name: "slug", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "prefix",
          type: "string",
          default: "",
          description: "Thread prefix (e.g. [Discussion], [Guide])"
        },
        %{name: "tags", type: "string", default: "", description: "Comma-separated tags to apply"}
      ]
    }
  end
end
