defmodule ForgeNexusWeb.CallController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Voice
  alias ForgeNexus.Chat

  def initiate(conn, %{"conversation_id" => conv_id} = params) do
    user = Guardian.Plug.current_resource(conn)
    type = params["type"] || "audio"

    case Voice.initiate_call(conv_id, user.id, type) do
      {:ok, call} ->
        # Get other participants to notify
        conversation = Chat.list_conversations(user.id) |> Enum.find(fn c -> c.id == conv_id end)

        if conversation do
          for participant <- conversation.participants do
            if participant.user_id != user.id do
              ForgeNexusWeb.Endpoint.broadcast("user:#{participant.user_id}", "incoming_call", %{
                call_id: call.id,
                conversation_id: conv_id,
                caller_id: user.id,
                caller_username: user.username,
                caller_avatar_url: user.avatar_url,
                type: type
              })
            end
          end
        end

        conn |> put_status(:created) |> json(%{call: call_json(call)})

      {:error, :call_in_progress} ->
        conn |> put_status(:conflict) |> json(%{error: "A call is already in progress"})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to initiate call"})
    end
  end

  def answer(conn, %{"id" => call_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Voice.answer_call(call_id, user.id) do
      {:ok, call} ->
        # Notify caller that the call was answered
        ForgeNexusWeb.Endpoint.broadcast("user:#{call.caller_id}", "call_answered", %{
          call_id: call.id,
          answered_by: user.id,
          answered_by_username: user.username
        })

        conn |> json(%{call: call_json(call)})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot answer this call"})
    end
  end

  def decline(conn, %{"id" => call_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Voice.decline_call(call_id) do
      {:ok, call} ->
        ForgeNexusWeb.Endpoint.broadcast("user:#{call.caller_id}", "call_declined", %{
          call_id: call.id,
          declined_by: user.id
        })

        conn |> json(%{call: call_json(call)})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot decline this call"})
    end
  end

  def hang_up(conn, %{"id" => call_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Voice.end_call(call_id) do
      {:ok, call} ->
        # Notify all participants
        for uid <- call.participant_ids, uid != user.id do
          ForgeNexusWeb.Endpoint.broadcast("user:#{uid}", "call_ended", %{
            call_id: call.id,
            ended_by: user.id
          })
        end

        conn |> json(%{call: call_json(call)})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot end this call"})
    end
  end

  def active(conn, %{"conversation_id" => conv_id}) do
    case Voice.get_active_call(conv_id) do
      nil -> conn |> json(%{call: nil})
      call -> conn |> json(%{call: call_json(call)})
    end
  end

  def history(conn, %{"conversation_id" => conv_id}) do
    calls = Voice.call_history(conv_id)
    conn |> json(%{calls: Enum.map(calls, &call_json/1)})
  end

  defp call_json(call) do
    %{
      id: call.id,
      conversation_id: call.conversation_id,
      caller_id: call.caller_id,
      caller:
        call.caller &&
          %{
            id: call.caller.id,
            username: call.caller.username,
            avatar_url: call.caller.avatar_url
          },
      status: call.status,
      type: call.type,
      started_at: call.started_at,
      answered_at: call.answered_at,
      ended_at: call.ended_at,
      participant_ids: call.participant_ids
    }
  end
end
